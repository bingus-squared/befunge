use crate::sim::{Direction, Grid, GridUpdate, Simulation};

mod sim;

fn main() {
    let grid = Grid::new_from_string(include_str!("examples/foo.txt"));
    let mut simulation = Simulation::new(grid);
    simulation.grid.apply(GridUpdate::SpawnCursor {
        id: 0,
        x: 0,
        y: 0,
        direction: Direction::Right,
        stack: vec![],
        energy: 1000,
        string_mode: false,
    });
    for _ in 0..10 {
        println!("{}================", simulation.grid);
        simulation.step();
    }
    println!("{}================", simulation.grid);
}
