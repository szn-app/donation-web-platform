// https://docs.rs/tower/latest/tower/trait.Service.html

mod auth;

use axum;

#[tokio::main]
async fn main() {
    // Build our application with a single route
    let app = auth::routes();

    // Run our application
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("Server running on http://0.0.0.0:3000");
    axum::serve(listener, app).await.unwrap();
}
