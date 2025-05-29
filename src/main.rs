use deadpool_postgres::{Config, Pool, Runtime};
use secrecy::ExposeSecret;
use tokio_postgres::NoTls;
use std::net::TcpListener;
use zero2prod::configuration::{get_configuration, DatabaseSettings};
use zero2prod::startup::run;
use zero2prod::telemetry::{get_subscriber, init_subscriber};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let subscriber = get_subscriber("zero2prod".into(), "info".into(), std::io::stdout);
    init_subscriber(subscriber);

    // Panic if configuration unreadable
    let configuration = get_configuration().expect("Failed to read configuration.");
    // create database connection pool
    let connection_pool = create_configuration_pool(&configuration.database)?;

    let address = format!(
        "{}:{}",
        configuration.application.host, configuration.application.port
    );

    let listener = TcpListener::bind(address)?;
    Ok(run(listener, connection_pool)?.await?)
}

fn create_configuration_pool(db_config: &DatabaseSettings) -> Result<Pool, Box<dyn std::error::Error>> {
    let mut cfg = Config::new();
    cfg.host = Some(db_config.host.clone());
    cfg.port = Some(db_config.port.clone());
    cfg.user = Some(db_config.username.clone());
    cfg.password = Some(db_config.password.expose_secret().clone());
    cfg.dbname = Some(db_config.database_name.clone());

    cfg.create_pool(Some(Runtime::Tokio1), NoTls).map_err(|e| e.into())
}
