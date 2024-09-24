use crate::sim::step::Simulation;
use crate::sim::subscription::{Subscriber, SubscriptionManager};
use crate::sim::{Cursor, Direction, Grid, GridUpdate, GridUpdateAction};
use anyhow::Result;
use axum::extract::ws::{Message, WebSocket};
use axum::extract::{ConnectInfo, State, WebSocketUpgrade};
use axum::response::IntoResponse;
use axum::routing::get;
use base64::prelude::BASE64_STANDARD;
use base64::Engine;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::env;
use std::net::SocketAddr;
use std::ops::Deref;
use std::sync::Arc;
use tokio::sync::{mpsc, Mutex};
use tower_http::services::{ServeDir, ServeFile};

mod sim;

pub struct AppState {
    pub tick_rate: Mutex<u64>,
    pub simulation: Mutex<Simulation>,
    pub subscription_manager: Mutex<SubscriptionManager<WebsocketSubscriber>>,
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

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
enum BfMessage {
    ChunkData {
        x: usize,
        y: usize,
        data: String,
        cursors: HashMap<usize, Cursor>,
    },
    Update(GridUpdate),
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
enum BfClientMessage {
    SubscribeChunk { x: usize, y: usize },
    UnsubscribeChunk { x: usize, y: usize },
}

pub struct WebsocketSubscriber {
    tx: mpsc::Sender<String>,
}

impl Subscriber for WebsocketSubscriber {
    fn notify(&self, updates: Vec<GridUpdate>) {
        self.tx
            .try_send(
                serde_json::to_string(
                    &updates
                        .into_iter()
                        .map(|e| BfMessage::Update(e))
                        .collect::<Vec<_>>(),
                )
                .unwrap(),
            )
            .unwrap();
    }
}

async fn ws_handler(
    state: State<Arc<AppState>>,
    ws: WebSocketUpgrade,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
) -> impl IntoResponse {
    ws.on_upgrade(move |socket| async move {
        let (tx, rx) = mpsc::channel(100);
        let mut subscription_manager = state.subscription_manager.lock().await;
        let id = subscription_manager.subscribe(WebsocketSubscriber { tx });
        drop(subscription_manager);
        match handle_socket(socket, addr, id, rx, state.deref().clone()).await {
            Ok(_) => (),
            Err(e) => eprintln!("Error on websocket for {:?}: {:?}", addr, e),
        }
        let mut subscription_manager = state.subscription_manager.lock().await;
        subscription_manager.remove_subscriber(id);
    })
}

async fn handle_client_message(
    socket: &mut WebSocket,
    message: BfClientMessage,
    id: usize,
    state: Arc<AppState>,
) {
    match message {
        BfClientMessage::SubscribeChunk { x, y } => {
            let mut subscription_manager = state.subscription_manager.lock().await;
            subscription_manager.subscribe_chunks(id, vec![(x, y)]);
            // Send the current state of the chunk to the client
            let simulation = state.simulation.lock().await;
            if let Some(chunk) = simulation.grid.chunks.get(&(x, y)) {
                let data = BASE64_STANDARD.encode(&chunk.cells);
                socket
                    .send(Message::Text(
                        serde_json::to_string(&BfMessage::ChunkData {
                            x,
                            y,
                            data,
                            cursors: chunk.cursors.clone(),
                        })
                        .unwrap(),
                    ))
                    .await
                    .unwrap();
            }
        }
        BfClientMessage::UnsubscribeChunk { x, y } => {
            let mut subscription_manager = state.subscription_manager.lock().await;
            subscription_manager.unsubscribe_chunk(id, x, y);
        }
    }
}

async fn handle_socket(
    mut socket: WebSocket,
    who: SocketAddr,
    id: usize,
    mut rx: mpsc::Receiver<String>,
    state: Arc<AppState>,
) -> Result<()> {
    loop {
        tokio::select! {
            msg = socket.recv() => {
                match msg {
                    None => break,
                    Some(msg) => {
                        match msg? {
                            Message::Text(s) => {
                                println!("Received message from {:?}: {}", who, s);
                                let message: BfClientMessage = serde_json::from_str(&s)?;
                                handle_client_message(&mut socket, message, id, state.clone()).await;
                            }
                            _ => {},
                        }
                    }
                }
            }
            msg = rx.recv() => {
                if let Some(msg) = msg {
                    socket.send(Message::Text(msg)).await?;
                }
            }
        }
    }
    Ok(())
}

#[tokio::main]
async fn main() -> Result<()> {
    let grid = Grid::new_from_string(include_str!("examples/foo.txt"));
    let mut simulation = Simulation::new(grid);
    simulation.grid.apply(GridUpdate {
        x: 0,
        y: 0,
        action: GridUpdateAction::SpawnCursor {
            id: 0,
            direction: Direction::Right,
            stack: vec![],
            energy: 1000,
            string_mode: false,
        },
    });
    let app_state = Arc::new(AppState {
        tick_rate: Mutex::new(1000),
        simulation: Mutex::new(simulation),
        subscription_manager: Mutex::new(SubscriptionManager::new()),
    });

    // Start a background thread that ticks the simulation
    let app_state_clone = app_state.clone();
    tokio::spawn(async move {
        loop {
            tokio::time::sleep(tokio::time::Duration::from_millis(
                *app_state_clone.tick_rate.lock().await,
            ))
            .await;
            let mut simulation = app_state_clone.simulation.lock().await;
            let updates = simulation.step();
            let subscription_manager = app_state_clone.subscription_manager.lock().await;
            subscription_manager.notify(updates);
        }
    });

    let port = 3000;
    start_http_server(port, app_state).await?;

    Ok(())
}
