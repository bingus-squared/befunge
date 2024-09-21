use crate::sim::{Direction, Grid, GridUpdate, GridUpdateAction, CHUNK_WIDTH};
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
                b'"' => self.updates.push(GridUpdate {
                    x: abs_x,
                    y: abs_y,
                    action: GridUpdateAction::ToggleStringMode { id },
                }),
                c => {
                    self.updates.push(GridUpdate {
                        x: abs_x,
                        y: abs_y,
                        action: GridUpdateAction::UpdateStack {
                            id,
                            pop: 0,
                            push: vec![c as i64],
                        },
                    });
                }
            }
        } else {
            match chunk.get(cursor.x, cursor.y) {
                b'^' => {
                    direction = Direction::Up;
                    self.updates.push(GridUpdate {
                        x: abs_x,
                        y: abs_y,
                        action: GridUpdateAction::ChangeDirection { id, direction },
                    });
                }
                b'v' => {
                    direction = Direction::Down;
                    self.updates.push(GridUpdate {
                        x: abs_x,
                        y: abs_y,
                        action: GridUpdateAction::ChangeDirection { id, direction },
                    });
                }
                b'<' => {
                    direction = Direction::Left;
                    self.updates.push(GridUpdate {
                        x: abs_x,
                        y: abs_y,
                        action: GridUpdateAction::ChangeDirection { id, direction },
                    });
                }
                b'>' => {
                    direction = Direction::Right;
                    self.updates.push(GridUpdate {
                        x: abs_x,
                        y: abs_y,
                        action: GridUpdateAction::ChangeDirection { id, direction },
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
                    self.updates.push(GridUpdate {
                        x: abs_x,
                        y: abs_y,
                        action: GridUpdateAction::ChangeDirection { id, direction },
                    });
                }
                _ => {}
            }
        }

        if cursor.energy == 0 {
            self.updates.push(GridUpdate {
                x: abs_x,
                y: abs_y,
                action: GridUpdateAction::DestroyCursor { id },
            });
            return;
        }

        self.updates.push(GridUpdate {
            x: abs_x,
            y: abs_y,
            action: GridUpdateAction::MoveCursor {
                id,
                to_x: match direction {
                    Direction::Left => abs_x - 1,
                    Direction::Right => abs_x + 1,
                    _ => abs_x,
                },
                to_y: match direction {
                    Direction::Up => abs_y - 1,
                    Direction::Down => abs_y + 1,
                    _ => abs_y,
                },
            },
        });

        self.updates.push(GridUpdate {
            x: abs_x,
            y: abs_y,
            action: GridUpdateAction::ConsumeEnergy { id, energy: 1 },
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
