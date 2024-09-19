pub mod step;
pub mod subscription;

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
    chunks: HashMap<(usize, usize), Chunk>,
    cursor_chunks: HashMap<usize, (usize, usize)>,
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
        pos: (usize, usize),
        c: u8,
    },
    MoveCursor {
        id: usize,
        pos: (usize, usize),
        to: (usize, usize),
    },
    SpawnCursor {
        id: usize,
        pos: (usize, usize),
        direction: Direction,
        stack: Vec<i64>,
        energy: usize,
        string_mode: bool,
    },
    DestroyCursor {
        id: usize,
        pos: (usize, usize),
    },
    UpdateStack {
        id: usize,
        pos: (usize, usize),
        pop: usize,
        push: Vec<i64>,
    },
    ToggleStringMode {
        id: usize,
        pos: (usize, usize),
    },
    ChangeDirection {
        id: usize,
        pos: (usize, usize),
        direction: Direction,
    },
    ConsumeEnergy {
        id: usize,
        pos: (usize, usize),
        energy: usize,
    },
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
            chunks: HashMap::new(),
            cursor_chunks: HashMap::new(),
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
        let chunk = self.chunks.get(&(chunk_x, chunk_y));
        match chunk {
            Some(chunk) => chunk.get(x % CHUNK_WIDTH, y % CHUNK_WIDTH),
            None => b' ',
        }
    }

    pub fn set_cell(&mut self, x: usize, y: usize, c: u8) {
        let chunk_x = x / CHUNK_WIDTH;
        let chunk_y = y / CHUNK_WIDTH;
        let chunk = self.get_chunk_mut(chunk_x, chunk_y);
        chunk.set(x % CHUNK_WIDTH, y % CHUNK_WIDTH, c);
    }

    pub fn get_cursor(&self, id: usize) -> Option<&Cursor> {
        let (chunk_x, chunk_y) = self.cursor_chunks[&id];
        let chunk = self.chunks.get(&(chunk_x, chunk_y));
        match chunk {
            Some(chunk) => chunk.cursors.get(&id),
            None => None,
        }
    }

    pub fn get_cursor_mut(&mut self, id: usize) -> Option<&mut Cursor> {
        let (chunk_x, chunk_y) = self.cursor_chunks[&id];
        let chunk = self.chunks.get_mut(&(chunk_x, chunk_y));
        match chunk {
            Some(chunk) => chunk.cursors.get_mut(&id),
            None => None,
        }
    }

    pub fn get_chunk_mut(&mut self, chunk_x: usize, chunk_y: usize) -> &mut Chunk {
        // Try finding an existing chunk, or create a new one
        self.chunks
            .entry((chunk_x, chunk_y))
            .or_insert_with(Chunk::new)
    }

    pub fn apply(&mut self, dt: GridUpdate) {
        match dt {
            GridUpdate::UpdateCell { pos: (x, y), c } => {
                self.set_cell(x, y, c);
            }
            GridUpdate::MoveCursor {
                id,
                pos: _from,
                to: (x, y),
            } => {
                let (cur_chunk_x, cur_chunk_y) = self.cursor_chunks[&id];
                let cur_chunk = self.chunks.get_mut(&(cur_chunk_x, cur_chunk_y)).unwrap();
                let new_chunk_x = x / CHUNK_WIDTH;
                let new_chunk_y = y / CHUNK_WIDTH;
                if cur_chunk_x != new_chunk_x || cur_chunk_y != new_chunk_y {
                    // Move cursor to a new chunk
                    let mut cursor = cur_chunk.cursors.remove(&id).unwrap();
                    cursor.x = x % CHUNK_WIDTH;
                    cursor.y = y % CHUNK_WIDTH;
                    let new_chunk = self.get_chunk_mut(new_chunk_x, new_chunk_y);
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
                pos: (x, y),
                direction,
                stack,
                energy,
                string_mode,
            } => {
                let chunk_x = x / CHUNK_WIDTH;
                let chunk_y = y / CHUNK_WIDTH;
                let chunk = self.get_chunk_mut(chunk_x, chunk_y);
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
            GridUpdate::DestroyCursor { id, pos: _pos } => {
                let (chunk_x, chunk_y) = self.cursor_chunks.remove(&id).unwrap();
                let chunk = self.chunks.get_mut(&(chunk_x, chunk_y)).unwrap();
                chunk.cursors.remove(&id);
            }
            GridUpdate::UpdateStack {
                id,
                pos: _pos,
                pop,
                push,
            } => {
                let cursor = self.get_cursor_mut(id).unwrap();
                for _ in 0..pop {
                    cursor.stack.pop();
                }
                for value in push {
                    cursor.stack.push(value);
                }
            }
            GridUpdate::ChangeDirection {
                id,
                pos: _pos,
                direction,
            } => {
                let cursor = self.get_cursor_mut(id).unwrap();
                cursor.direction = direction;
            }
            GridUpdate::ConsumeEnergy {
                id,
                pos: _pos,
                energy,
            } => {
                let cursor = self.get_cursor_mut(id).unwrap();
                cursor.energy -= energy;
            }
            GridUpdate::ToggleStringMode { id, pos: _pos } => {
                let cursor = self.get_cursor_mut(id).unwrap();
                cursor.string_mode = !cursor.string_mode;
            }
        }
    }
}

impl Display for Grid {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        if self.chunks.len() == 0 {
            return Ok(());
        }
        let mut min_chunk_x = usize::MAX;
        let mut max_chunk_x = usize::MIN;
        let mut min_chunk_y = usize::MAX;
        let mut max_chunk_y = usize::MIN;
        for (chunk_x, chunk_y) in self.chunks.keys() {
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
            .chunks
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

impl GridUpdate {
    pub fn visit_chunks<F: FnMut(usize, usize)>(&self, mut cond: F) {
        match self {
            GridUpdate::UpdateCell { pos: (x, y), c: _ } => cond(x / CHUNK_WIDTH, y / CHUNK_WIDTH),
            GridUpdate::MoveCursor {
                pos: (x, y),
                to: (x2, y2),
                ..
            } => {
                let chunk_x = x / CHUNK_WIDTH;
                let chunk_y = y / CHUNK_WIDTH;
                let chunk_x2 = x2 / CHUNK_WIDTH;
                let chunk_y2 = y2 / CHUNK_WIDTH;
                cond(chunk_x, chunk_y);
                if chunk_x != chunk_x2 || chunk_y != chunk_y2 {
                    cond(chunk_x2, chunk_y2);
                }
            }
            GridUpdate::SpawnCursor { pos: (x, y), .. } => cond(x / CHUNK_WIDTH, y / CHUNK_WIDTH),
            GridUpdate::DestroyCursor { id: _, pos: (x, y) } => {
                cond(x / CHUNK_WIDTH, y / CHUNK_WIDTH)
            }
            GridUpdate::UpdateStack { pos: (x, y), .. } => cond(x / CHUNK_WIDTH, y / CHUNK_WIDTH),
            GridUpdate::ToggleStringMode { id: _, pos: (x, y) } => {
                cond(x / CHUNK_WIDTH, y / CHUNK_WIDTH)
            }
            GridUpdate::ChangeDirection { pos: (x, y), .. } => {
                cond(x / CHUNK_WIDTH, y / CHUNK_WIDTH)
            }
            GridUpdate::ConsumeEnergy { pos: (x, y), .. } => cond(x / CHUNK_WIDTH, y / CHUNK_WIDTH),
        }
    }
}
