use crate::sim::{Direction, Grid, GridUpdate, CHUNK_WIDTH};
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

        if cursor.string_mode {
            match chunk.get(cursor.x, cursor.y) {
                b'"' => self.updates.push(GridUpdate::ToggleStringMode {
                    id,
                    pos: (abs_x, abs_y),
                }),
                c => {
                    self.updates.push(GridUpdate::UpdateStack {
                        id,
                        pos: (abs_x, abs_y),
                        pop: 0,
                        push: vec![c as i64],
                    });
                }
            }
        } else {
            match chunk.get(cursor.x, cursor.y) {
                b'^' => {
                    direction = Direction::Up;
                    self.updates.push(GridUpdate::ChangeDirection {
                        id,
                        pos: (abs_x, abs_y),
                        direction,
                    });
                }
                b'v' => {
                    direction = Direction::Down;
                    self.updates.push(GridUpdate::ChangeDirection {
                        id,
                        pos: (abs_x, abs_y),
                        direction,
                    });
                }
                b'<' => {
                    direction = Direction::Left;
                    self.updates.push(GridUpdate::ChangeDirection {
                        id,
                        pos: (abs_x, abs_y),
                        direction,
                    });
                }
                b'>' => {
                    direction = Direction::Right;
                    self.updates.push(GridUpdate::ChangeDirection {
                        id,
                        pos: (abs_x, abs_y),
                        direction,
                    });
                }
                b'?' => {
                    direction = match self.rng.gen_range(0..4) {
                        0 => Direction::Up,
                        1 => Direction::Down,
                        2 => Direction::Left,
                        3 => Direction::Right,
                        _ => unreachable!(),
                    };
                    self.updates.push(GridUpdate::ChangeDirection {
                        id,
                        pos: (abs_x, abs_y),
                        direction,
                    });
                }
                _ => {}
            }
        }

        if cursor.energy == 0 {
            self.updates.push(GridUpdate::DestroyCursor {
                id,
                pos: (abs_x, abs_y),
            });
            return;
        }

        self.updates.push(GridUpdate::MoveCursor {
            id,
            pos: (abs_x, abs_y),
            to: (
                match direction {
                    Direction::Left => abs_x - 1,
                    Direction::Right => abs_x + 1,
                    _ => abs_x,
                },
                match direction {
                    Direction::Up => abs_y - 1,
                    Direction::Down => abs_y + 1,
                    _ => abs_y,
                },
            ),
        });

        self.updates.push(GridUpdate::ConsumeEnergy {
            id,
            pos: (abs_x, abs_y),
            energy: 1,
        });
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
        for update in updates.iter() {
            println!("{:?}", update);
            self.grid.apply(update.clone());
        }
        updates
    }
}
