use rand::rngs::SmallRng;
use rand::{Rng, SeedableRng};
use std::collections::{HashMap, HashSet};
use std::fmt::Display;

const CHUNK_WIDTH: usize = 64;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Cursor {
    // Position is relative to the chunk
    x: usize,
    y: usize,
    direction: Direction,
    stack: Vec<i64>,
    energy: usize,
    string_mode: bool,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Chunk {
    cells: [u8; CHUNK_WIDTH * CHUNK_WIDTH],
    cursors: HashMap<usize, Cursor>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Grid {
    inactive_chunks: HashMap<(usize, usize), Chunk>,
    active_chunks: HashMap<(usize, usize), Chunk>,
    cursor_chunks: HashMap<usize, (usize, usize)>,
    previous_chunks: HashMap<(usize, usize), Chunk>,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Direction {
    Up,
    Down,
    Left,
    Right,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum GridUpdate {
    UpdateCell {
        x: usize,
        y: usize,
        c: u8,
    },
    MoveCursor {
        id: usize,
        x: usize,
        y: usize,
    },
    SpawnCursor {
        id: usize,
        x: usize,
        y: usize,
        direction: Direction,
        stack: Vec<i64>,
        energy: usize,
        string_mode: bool,
    },
    DestroyCursor {
        id: usize,
    },
    UpdateStack {
        id: usize,
        pop: usize,
        push: Vec<i64>,
    },
    ToggleStringMode {
        id: usize,
    },
    ChangeDirection {
        id: usize,
        direction: Direction,
    },
    ConsumeEnergy {
        id: usize,
        energy: usize,
    },
}

pub struct ChunkDelta {
    pub chunk_pos: (usize, usize),
    pub cursors: Vec<(usize, Option<Cursor>)>,
    pub cells: Vec<(usize, usize, u8)>,
}

pub struct GridDelta {
    pub chunks: Vec<((usize, usize), ChunkDelta)>,
}

impl Chunk {
    pub fn new() -> Chunk {
        Chunk {
            cells: [b' '; CHUNK_WIDTH * CHUNK_WIDTH],
            cursors: HashMap::new(),
        }
    }

    pub fn get(&self, x: usize, y: usize) -> u8 {
        self.cells[y * CHUNK_WIDTH + x]
    }

    pub fn set(&mut self, x: usize, y: usize, c: u8) {
        self.cells[y * CHUNK_WIDTH + x] = c;
    }
}

impl Grid {
    pub fn new() -> Grid {
        Grid {
            inactive_chunks: HashMap::new(),
            active_chunks: HashMap::new(),
            cursor_chunks: HashMap::new(),
            previous_chunks: HashMap::new(),
        }
    }

    pub fn new_from_string(s: &str) -> Grid {
        let mut grid = Grid::new();
        let mut x = 0;
        let mut y = 0;
        for c in s.chars() {
            if c == '\n' {
                x = 0;
                y += 1;
            } else {
                grid.set_cell(x, y, c as u8);
                x += 1;
            }
        }
        grid
    }

    pub fn get_cell(&self, x: usize, y: usize) -> u8 {
        let chunk_x = x / CHUNK_WIDTH;
        let chunk_y = y / CHUNK_WIDTH;
        let chunk = self
            .active_chunks
            .get(&(chunk_x, chunk_y))
            .or_else(|| self.inactive_chunks.get(&(chunk_x, chunk_y)));
        match chunk {
            Some(chunk) => chunk.get(x % CHUNK_WIDTH, y % CHUNK_WIDTH),
            None => b' ',
        }
    }

    fn dirty_chunk(&mut self, chunk_x: usize, chunk_y: usize) {
        if !self.previous_chunks.contains_key(&(chunk_x, chunk_y)) {
            if let Some(chunk) = self
                .active_chunks
                .get(&(chunk_x, chunk_y))
                .or(self.inactive_chunks.get(&(chunk_x, chunk_y)))
            {
                self.previous_chunks
                    .insert((chunk_x, chunk_y), chunk.clone());
            }
        }
    }

    fn dirty_cursor(&mut self, id: usize) {
        let (chunk_x, chunk_y) = self.cursor_chunks[&id];
        self.dirty_chunk(chunk_x, chunk_y);
    }

    pub fn set_cell(&mut self, x: usize, y: usize, c: u8) {
        let chunk_x = x / CHUNK_WIDTH;
        let chunk_y = y / CHUNK_WIDTH;
        let chunk = self.get_inactive_chunk_mut(chunk_x, chunk_y);
        chunk.set(x % CHUNK_WIDTH, y % CHUNK_WIDTH, c);
    }

    pub fn get_cursor(&self, id: usize) -> Option<&Cursor> {
        let (chunk_x, chunk_y) = self.cursor_chunks[&id];
        let chunk = self.active_chunks.get(&(chunk_x, chunk_y));
        match chunk {
            Some(chunk) => chunk.cursors.get(&id),
            None => None,
        }
    }

    pub fn get_cursor_mut(&mut self, id: usize) -> Option<&mut Cursor> {
        let (chunk_x, chunk_y) = self.cursor_chunks[&id];
        let chunk = self.active_chunks.get_mut(&(chunk_x, chunk_y));
        match chunk {
            Some(chunk) => chunk.cursors.get_mut(&id),
            None => None,
        }
    }

    pub fn get_active_chunk_mut(&mut self, chunk_x: usize, chunk_y: usize) -> &mut Chunk {
        // Try to find an existing active chunk
        self.active_chunks
            .entry((chunk_x, chunk_y))
            .or_insert_with(|| {
                // Promote chunk from inactive to active
                self.inactive_chunks
                    .remove(&(chunk_x, chunk_y))
                    .unwrap_or_else(|| Chunk::new())
            })
    }

    pub fn get_inactive_chunk_mut(&mut self, chunk_x: usize, chunk_y: usize) -> &mut Chunk {
        // Try to find an existing active chunk
        match self.active_chunks.get_mut(&(chunk_x, chunk_y)) {
            Some(chunk) => chunk,
            None => {
                // Try to find an existing inactive chunk, or create a new one
                self.inactive_chunks
                    .entry((chunk_x, chunk_y))
                    .or_insert_with(Chunk::new)
            }
        }
    }

    pub fn apply(&mut self, dt: GridUpdate) {
        match dt {
            GridUpdate::UpdateCell { x, y, c } => {
                self.set_cell(x, y, c);
            }
            GridUpdate::MoveCursor { id, x, y } => {
                let (cur_chunk_x, cur_chunk_y) = self.cursor_chunks[&id];
                self.dirty_chunk(cur_chunk_x, cur_chunk_y);
                let cur_chunk = self
                    .active_chunks
                    .get_mut(&(cur_chunk_x, cur_chunk_y))
                    .unwrap();
                let new_chunk_x = x / CHUNK_WIDTH;
                let new_chunk_y = y / CHUNK_WIDTH;
                if cur_chunk_x != new_chunk_x || cur_chunk_y != new_chunk_y {
                    // Move cursor to a new chunk
                    let mut cursor = cur_chunk.cursors.remove(&id).unwrap();
                    if cur_chunk.cursors.len() == 0 {
                        // Demote chunk from active to inactive
                        let chunk = self
                            .active_chunks
                            .remove(&(cur_chunk_x, cur_chunk_y))
                            .unwrap();
                        self.inactive_chunks
                            .insert((cur_chunk_x, cur_chunk_y), chunk);
                    }
                    cursor.x = x % CHUNK_WIDTH;
                    cursor.y = y % CHUNK_WIDTH;
                    self.dirty_chunk(new_chunk_x, new_chunk_y);
                    let new_chunk = self.get_active_chunk_mut(new_chunk_x, new_chunk_y);
                    new_chunk.cursors.insert(id, cursor);

                    // Update cursor chunk
                    self.cursor_chunks.insert(id, (new_chunk_x, new_chunk_y));
                } else {
                    // Move cursor within the same chunk
                    let cursor = cur_chunk.cursors.get_mut(&id).unwrap();
                    cursor.x = x % CHUNK_WIDTH;
                    cursor.y = y % CHUNK_WIDTH;
                }
            }
            GridUpdate::SpawnCursor {
                id,
                x,
                y,
                direction,
                stack,
                energy,
                string_mode,
            } => {
                let chunk_x = x / CHUNK_WIDTH;
                let chunk_y = y / CHUNK_WIDTH;
                self.dirty_chunk(chunk_x, chunk_y);
                let chunk = self.get_active_chunk_mut(chunk_x, chunk_y);
                chunk.cursors.insert(
                    id,
                    Cursor {
                        x: x % CHUNK_WIDTH,
                        y: y % CHUNK_WIDTH,
                        direction,
                        stack,
                        energy,
                        string_mode,
                    },
                );
                self.cursor_chunks.insert(id, (chunk_x, chunk_y));
            }
            GridUpdate::DestroyCursor { id } => {
                let (chunk_x, chunk_y) = self.cursor_chunks.remove(&id).unwrap();
                self.dirty_chunk(chunk_x, chunk_y);
                let chunk = self.active_chunks.get_mut(&(chunk_x, chunk_y)).unwrap();
                chunk.cursors.remove(&id);
                if chunk.cursors.len() == 0 {
                    // Demote chunk from active to inactive
                    let chunk = self.active_chunks.remove(&(chunk_x, chunk_y)).unwrap();
                    self.inactive_chunks.insert((chunk_x, chunk_y), chunk);
                }
            }
            GridUpdate::UpdateStack { id, pop, push } => {
                self.dirty_cursor(id);
                let cursor = self.get_cursor_mut(id).unwrap();
                for _ in 0..pop {
                    cursor.stack.pop();
                }
                for value in push {
                    cursor.stack.push(value);
                }
            }
            GridUpdate::ChangeDirection { id, direction } => {
                self.dirty_cursor(id);
                let cursor = self.get_cursor_mut(id).unwrap();
                cursor.direction = direction;
            }
            GridUpdate::ConsumeEnergy { id, energy } => {
                self.dirty_cursor(id);
                let cursor = self.get_cursor_mut(id).unwrap();
                cursor.energy -= energy;
            }
            GridUpdate::ToggleStringMode { id } => {
                self.dirty_cursor(id);
                let cursor = self.get_cursor_mut(id).unwrap();
                cursor.string_mode = !cursor.string_mode;
            }
        }
    }

    pub fn get_delta(&mut self) -> GridDelta {
        let mut chunks = Vec::new();
        for ((chunk_x, chunk_y), old_chunk) in self.previous_chunks.iter() {
            let mut chunk_delta = ChunkDelta {
                chunk_pos: (*chunk_x, *chunk_y),
                cursors: Vec::new(),
                cells: Vec::new(),
            };
            let chunk = self
                .active_chunks
                .get(&(*chunk_x, *chunk_y))
                .or(self.inactive_chunks.get(&(*chunk_x, *chunk_y)));
            let mut ids = old_chunk.cursors.keys().collect::<HashSet<_>>();
            if let Some(new_chunk) = chunk {
                ids.extend(new_chunk.cursors.keys());
            }
            for id in ids {
                let old_cursor = old_chunk.cursors.get(id);
                let new_cursor = self
                    .active_chunks
                    .get(&(*chunk_x, *chunk_y))
                    .or(self.inactive_chunks.get(&(*chunk_x, *chunk_y)))
                    .and_then(|chunk| chunk.cursors.get(id));
                if old_cursor != new_cursor {
                    chunk_delta.cursors.push((*id, new_cursor.cloned()));
                }
            }
            if let Some(chunk) = chunk {
                for y in 0..CHUNK_WIDTH {
                    for x in 0..CHUNK_WIDTH {
                        let c = chunk.get(x, y);
                        if c != old_chunk.get(x, y) {
                            chunk_delta.cells.push((x, y, c));
                        }
                    }
                }
            } else {
                for y in 0..CHUNK_WIDTH {
                    for x in 0..CHUNK_WIDTH {
                        if old_chunk.get(x, y) != b' ' {
                            chunk_delta.cells.push((x, y, b' '));
                        }
                    }
                }
            }
            chunks.push(((*chunk_x, *chunk_y), chunk_delta));
        }
        GridDelta { chunks }
    }
}

impl Display for Grid {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        if self.active_chunks.len() == 0 && self.inactive_chunks.len() == 0 {
            return Ok(());
        }
        let mut min_chunk_x = usize::MAX;
        let mut max_chunk_x = usize::MIN;
        let mut min_chunk_y = usize::MAX;
        let mut max_chunk_y = usize::MIN;
        for (chunk_x, chunk_y) in self.active_chunks.keys().chain(self.inactive_chunks.keys()) {
            min_chunk_x = min_chunk_x.min(*chunk_x);
            max_chunk_x = max_chunk_x.max(*chunk_x);
            min_chunk_y = min_chunk_y.min(*chunk_y);
            max_chunk_y = max_chunk_y.max(*chunk_y);
        }

        let mut min_x = usize::MAX;
        let mut max_x = usize::MIN;
        let mut min_y = usize::MAX;
        let mut max_y = usize::MIN;
        for y in min_chunk_y * CHUNK_WIDTH..max_chunk_y * CHUNK_WIDTH + CHUNK_WIDTH {
            for x in min_chunk_x * CHUNK_WIDTH..max_chunk_x * CHUNK_WIDTH + CHUNK_WIDTH {
                match self.get_cell(x, y) {
                    b' ' => {}
                    _ => {
                        min_x = min_x.min(x);
                        max_x = max_x.max(x);
                        min_y = min_y.min(y);
                        max_y = max_y.max(y);
                    }
                }
            }
        }

        let cursor_positions = self
            .active_chunks
            .iter()
            .flat_map(|((chunk_x, chunk_y), chunk)| {
                chunk.cursors.values().map(move |cursor| {
                    (
                        (chunk_x * CHUNK_WIDTH) + cursor.x,
                        (chunk_y * CHUNK_WIDTH) + cursor.y,
                    )
                })
            })
            .collect::<HashSet<(usize, usize)>>();

        let mut lines = vec![];
        for y in min_y..=max_y {
            let mut line = String::new();
            for x in min_x..=max_x {
                if cursor_positions.contains(&(x, y)) {
                    line.extend("\x1b[7m".chars());
                    line.push(self.get_cell(x, y) as char);
                    line.extend("\x1b[0m".chars());
                } else {
                    line.push(self.get_cell(x, y) as char);
                }
            }
            lines.push(line);
        }
        for line in lines {
            writeln!(f, "{}", line)?;
        }
        Ok(())
    }
}

struct SimulationStep<'g> {
    updates: Vec<GridUpdate>,
    rng: &'g mut SmallRng,
    grid: &'g Grid,
}

impl SimulationStep<'_> {
    pub fn step_chunk(&mut self, chunk_pos: (usize, usize), chunk: &Chunk) {
        let chunk_abs_x = chunk_pos.0 * CHUNK_WIDTH;
        let chunk_abs_y = chunk_pos.1 * CHUNK_WIDTH;
        for (id, cursor) in chunk.cursors.iter() {
            let mut direction = cursor.direction;

            if cursor.string_mode {
                match chunk.get(cursor.x, cursor.y) {
                    b'"' => self.updates.push(GridUpdate::ToggleStringMode { id: *id }),
                    c => {
                        self.updates.push(GridUpdate::UpdateStack {
                            id: *id,
                            pop: 0,
                            push: vec![c as i64],
                        });
                    }
                }
            } else {
                match chunk.get(cursor.x, cursor.y) {
                    b'^' => {
                        direction = Direction::Up;
                        self.updates
                            .push(GridUpdate::ChangeDirection { id: *id, direction });
                    }
                    b'v' => {
                        direction = Direction::Down;
                        self.updates
                            .push(GridUpdate::ChangeDirection { id: *id, direction });
                    }
                    b'<' => {
                        direction = Direction::Left;
                        self.updates
                            .push(GridUpdate::ChangeDirection { id: *id, direction });
                    }
                    b'>' => {
                        direction = Direction::Right;
                        self.updates
                            .push(GridUpdate::ChangeDirection { id: *id, direction });
                    }
                    b'?' => {
                        direction = match self.rng.gen_range(0..4) {
                            0 => Direction::Up,
                            1 => Direction::Down,
                            2 => Direction::Left,
                            3 => Direction::Right,
                            _ => unreachable!(),
                        };
                        self.updates
                            .push(GridUpdate::ChangeDirection { id: *id, direction });
                    }
                    _ => {}
                }
            }

            if cursor.energy == 0 {
                self.updates.push(GridUpdate::DestroyCursor { id: *id });
                continue;
            }

            let abs_x = cursor.x + chunk_abs_x;
            let abs_y = cursor.y + chunk_abs_y;
            self.updates.push(GridUpdate::MoveCursor {
                id: *id,
                x: match direction {
                    Direction::Left => abs_x - 1,
                    Direction::Right => abs_x + 1,
                    _ => abs_x,
                },
                y: match direction {
                    Direction::Up => abs_y - 1,
                    Direction::Down => abs_y + 1,
                    _ => abs_y,
                },
            });

            self.updates
                .push(GridUpdate::ConsumeEnergy { id: *id, energy: 1 });
        }
    }

    pub fn step_grid(&mut self) {
        for (chunk_pos, chunk) in self.grid.active_chunks.iter() {
            self.step_chunk(*chunk_pos, chunk);
        }
    }
}

pub struct Simulation {
    rng: SmallRng,
    pub grid: Grid,
}

impl Simulation {
    pub fn new(grid: Grid) -> Simulation {
        Simulation {
            rng: SmallRng::from_entropy(),
            grid,
        }
    }

    pub fn step(&mut self) -> GridDelta {
        let mut step = SimulationStep {
            updates: Vec::new(),
            rng: &mut self.rng,
            grid: &self.grid,
        };
        step.step_grid();
        for update in step.updates {
            println!("{:?}", update);
            self.grid.apply(update);
        }
        self.grid.get_delta()
    }
}
