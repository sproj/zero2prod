use crate::configuration::{DatabaseSettings, Settings};
use crate::email_client::EmailClient;
use crate::routes::{health_check, subscribe};
use actix_web::dev::Server;
use actix_web::web::Data;
use actix_web::{web, App, HttpServer};
use deadpool_postgres::{Config, Pool, Runtime};
use secrecy::ExposeSecret;
use std::net::TcpListener;
use tokio_postgres::NoTls;
use tracing_actix_web::TracingLogger;

pub async fn build(configuration: Settings) -> Result<Server, Box<dyn std::error::Error>> {
    // create database connection pool
    let connection_pool = create_configuration_pool(&configuration.database)?;

    // Build an `EmailClient` using `configuration`
    let sender_email = configuration
        .email_client
        .sender()
        .expect("Invalid sender email address");

    let timeout = configuration.email_client.timeout();
    let email_client = EmailClient::new(
        configuration.email_client.base_url,
        sender_email,
        configuration.email_client.authorization_token,
        timeout,
    );

    let address = format!(
        "{}:{}",
        configuration.application.host, configuration.application.port
    );

    let listener = TcpListener::bind(address)?;
    run(listener, connection_pool, email_client)
}

fn create_configuration_pool(
    db_config: &DatabaseSettings,
) -> Result<Pool, Box<dyn std::error::Error>> {
    let mut cfg = Config::new();
    cfg.host = Some(db_config.host.clone());
    cfg.port = Some(db_config.port);
    cfg.user = Some(db_config.username.clone());
    cfg.password = Some(db_config.password.expose_secret().clone());
    cfg.dbname = Some(db_config.database_name.clone());

    cfg.create_pool(Some(Runtime::Tokio1), NoTls)
        .map_err(|e| e.into())
}

pub fn run(
    listener: TcpListener,
    db_pool: Pool,
    email_client: EmailClient,
) -> Result<Server, Box<dyn std::error::Error>> {
    let db_pool = web::Data::new(db_pool);

    let email_client = Data::new(email_client);
    let server = HttpServer::new(move || {
        App::new()
            .wrap(TracingLogger::default())
            .route("/health_check", web::get().to(health_check))
            .route("/subscriptions", web::post().to(subscribe))
            // register db connection as part of application state
            .app_data(db_pool.clone())
            .app_data(email_client.clone())
    })
    .listen(listener)?
    .run();

    Ok(server)
}
