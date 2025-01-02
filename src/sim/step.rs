use crate::sim::{Direction, Grid, GridUpdate, GridUpdateAction, CHUNK_LIMIT, CHUNK_WIDTH};
use rand::prelude::SmallRng;
use rand::{Rng, SeedableRng};

struct SimulationStep<'g> {
    updates: Vec<GridUpdate>,
    rng: &'g mut SmallRng,
    grid: &'g Grid,
}

impl SimulationStep<'_> {
    pub fn step_cursor(&mut self, id: usize, chunk_pos: (usize, usize)) {
        let chunk = self.grid.chunks.get(&chunk_pos).unwrap();
        let cursor = chunk.cursors.get(&id).unwrap();

        let mut direction = cursor.direction;
        let abs_x = cursor.x + chunk_pos.0 * CHUNK_WIDTH;
        let abs_y = cursor.y + chunk_pos.1 * CHUNK_WIDTH;

        let mut push_update = |action| {
            self.updates.push(GridUpdate {
                x: abs_x,
                y: abs_y,
                action,
            });
        };

        if cursor.string_mode {
            match chunk.get(cursor.x, cursor.y) {
                b'"' => push_update(GridUpdateAction::ToggleStringMode { id }),
                c => {
                    push_update(GridUpdateAction::UpdateStack {
                        id,
                        pop: 0,
                        push: vec![c as i64],
                    });
                }
            }
        } else {
            match chunk.get(cursor.x, cursor.y) {
                b'^' => {
                    direction = Direction::Up;
                    push_update(GridUpdateAction::ChangeDirection { id, direction });
                }
                b'v' => {
                    direction = Direction::Down;
                    push_update(GridUpdateAction::ChangeDirection { id, direction });
                }
                b'<' => {
                    direction = Direction::Left;
                    push_update(GridUpdateAction::ChangeDirection { id, direction });
                }
                b'>' => {
                    direction = Direction::Right;
                    push_update(GridUpdateAction::ChangeDirection { id, direction });
                }
                b'?' => {
                    direction = match self.rng.gen_range(0..4) {
                        0 => Direction::Up,
                        1 => Direction::Down,
                        2 => Direction::Left,
                        3 => Direction::Right,
                        _ => unreachable!(),
                    };
                    push_update(GridUpdateAction::ChangeDirection { id, direction });
                }
                _ => {}
            }
        }

        if cursor.energy == 0 {
            push_update(GridUpdateAction::DestroyCursor { id });
            return;
        }

        let to_x = match direction {
            Direction::Left => cursor.x.checked_sub(1),
            Direction::Right => cursor.x.checked_add(1),
            _ => Some(cursor.x),
        };
        let to_y = match direction {
            Direction::Up => cursor.y.checked_sub(1),
            Direction::Down => cursor.y.checked_add(1),
            _ => Some(cursor.y),
        };

        match (to_x, to_y) {
            (Some(to_x), Some(to_y))
                if to_x < CHUNK_WIDTH * CHUNK_LIMIT && to_y < CHUNK_WIDTH * CHUNK_LIMIT =>
            {
                push_update(GridUpdateAction::MoveCursor { id, to_x, to_y });
            }
            _ => {
                push_update(GridUpdateAction::DestroyCursor { id });
                return;
            }
        }

        push_update(GridUpdateAction::ConsumeEnergy { id, energy: 1 });
    }

    pub fn step_grid(&mut self) {
        for (id, chunk_pos) in self.grid.cursor_chunks.iter() {
            self.step_cursor(*id, *chunk_pos);
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

    pub fn step(&mut self) -> Vec<GridUpdate> {
        let mut step = SimulationStep {
            updates: Vec::new(),
            rng: &mut self.rng,
            grid: &self.grid,
        };
        step.step_grid();
        let updates = step.updates;
        self.grid.tick += 1;
        for update in updates.iter() {
            println!("{:?}", update);
            self.grid.apply(update.clone());
        }
        updates
    }
}
