use crate::sim::{Direction, Grid, GridUpdate, Simulation};
use anyhow::Result;
use axum::extract::ws::{Message, WebSocket};
use axum::extract::{ConnectInfo, State, WebSocketUpgrade};
use axum::response::IntoResponse;
use axum::routing::get;
use std::env;
use std::net::SocketAddr;
use std::sync::Arc;
use tower_http::services::{ServeDir, ServeFile};

mod sim;

pub struct AppState {
    pub tick_rate: Arc<i64>,
    pub simulation: Arc<Simulation>,
}

pub async fn start_http_server(port: u16, state: Arc<AppState>) -> Result<()> {
    let manifest_dir = env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR not set");
    let client_build_dir = format!("{manifest_dir}/client/build");
    let not_found_file = format!("{client_build_dir}/404.html");

    let router = axum::Router::new()
        .route("/ws", get(ws_handler))
        .fallback_service(
            ServeDir::new(client_build_dir).not_found_service(ServeFile::new(not_found_file)),
        )
        .with_state(state.clone());

    let listen_address = format!("0.0.0.0:{}", port);
    let listener = tokio::net::TcpListener::bind(&listen_address).await?;
    println!("Server listening on {}", listen_address);
    axum::serve(
        listener,
        router.into_make_service_with_connect_info::<SocketAddr>(),
    )
    .await?;
    Ok(())
}

async fn ws_handler(
    state: State<Arc<AppState>>,
    ws: WebSocketUpgrade,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
) -> impl IntoResponse {
    ws.on_upgrade(move |socket| async move {
        match handle_socket(socket, addr).await {
            Ok(_) => (),
            Err(e) => eprintln!("Error on websocket for {:?}: {:?}", addr, e),
        }
    })
}

async fn handle_socket(mut socket: WebSocket, who: SocketAddr) -> Result<()> {
    while let Some(msg) = socket.recv().await {
        let msg = msg?.into_text()?;
        socket.send(Message::Text(msg)).await?;
    }
    Ok(())
}

#[tokio::main]
async fn main() -> Result<()> {
    let grid = Grid::new_from_string(include_str!("examples/foo.txt"));
    let mut simulation = Simulation::new(grid);
    simulation.grid.apply(GridUpdate::SpawnCursor {
        id: 0,
        pos: (0, 0),
        direction: Direction::Right,
        stack: vec![],
        energy: 1000,
        string_mode: false,
    });
    let app_state = Arc::new(AppState {
        tick_rate: Arc::new(1000),
        simulation: Arc::new(simulation),
    });
    let port = 3000;
    start_http_server(port, app_state).await?;

     // let grid = Grid::new_from_string(include_str!("examples/foo.txt"));
     // let mut simulation = Simulation::new(grid);
     // simulation.grid.apply(GridUpdate::SpawnCursor {
     //     id: 0,
     //     pos: (0, 0),
     //     direction: Direction::Right,
     //     stack: vec![],
     //     energy: 1000,
     //     string_mode: false,
     // });
     // for _ in 0..10 {
     //     println!("{}================", simulation.grid);
     //     simulation.step();
     // }
     // println!("{}================", simulation.grid);

    Ok(())
}
