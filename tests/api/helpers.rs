use deadpool_postgres::{Config, Pool, Runtime};
use tokio_postgres::NoTls;
use uuid::Uuid;
use zero2prod::{configuration::get_configuration, email_client::EmailClient};

pub struct TestDatabase {
    pub database_name: String,
    pub pool: Pool,
}

impl TestDatabase {
    pub async fn new() -> Self {
        let database_name = Uuid::new_v4().to_string();
        let pool = setup_test_database(&database_name).await;

        Self {
            database_name,
            pool,
        }
    }
}

impl Drop for TestDatabase {
    fn drop(&mut self) {
        // Cleanup happens here when TestDatabase goes out of scope
        let db_name = self.database_name.clone();
        tokio::spawn(async move {
            cleanup_test_database(&db_name).await;
        });
    }
}

async fn setup_test_database(database_name: &str) -> Pool {
    // Create the database
    create_test_database(database_name).await;

    // Create connection pool
    let pool = create_test_pool(database_name).await;

    // Run migrations
    run_migrations(&pool).await;

    pool
}

async fn create_test_database(database_name: &str) {
    let connection_string = "postgres://postgres:password@localhost:5432/postgres";

    let (client, connection) = tokio_postgres::connect(connection_string, NoTls)
        .await
        .expect("Failed to connect to Postgres for database creation");

    tokio::spawn(async move {
        if let Err(e) = connection.await {
            eprintln!("Connection error: {}", e);
        }
    });

    let query = format!("CREATE DATABASE \"{}\"", database_name);
    client
        .execute(&query, &[])
        .await
        .expect("Failed to create test database");
}

async fn create_test_pool(database_name: &str) -> Pool {
    let mut cfg = Config::new();
    cfg.host = Some("localhost".to_string());
    cfg.port = Some(5432);
    cfg.user = Some("postgres".to_string());
    cfg.password = Some("password".to_string());
    cfg.dbname = Some(database_name.to_string());

    cfg.create_pool(Some(Runtime::Tokio1), NoTls)
        .expect("Failed to create connection pool")
}

async fn run_migrations(pool: &Pool) {
    let client = pool.get().await.expect("Failed to get client");

    let migration_sql =
        std::fs::read_to_string("migrations/20250130200119_create_subscriptions_table.sql")
            .expect("Failed to read migration file");

    client
        .execute(&migration_sql, &[])
        .await
        .expect("Failed to execute migration");
}

async fn cleanup_test_database(database_name: &str) {
    let connection_string = "postgres://postgres:password@localhost:5432/postgres";

    let (client, connection) = tokio_postgres::connect(connection_string, NoTls)
        .await
        .expect("Failed to connect to Postgres for cleanup");

    tokio::spawn(async move {
        if let Err(e) = connection.await {
            eprintln!("Connection error: {}", e);
        }
    });

    // Terminate active connections to the database before dropping
    let terminate_query = format!(
        "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '{}' AND pid <> pg_backend_pid()",
        database_name
    );
    let _ = client.execute(&terminate_query, &[]).await;

    // Drop the database
    let drop_query = format!("DROP DATABASE IF EXISTS \"{}\"", database_name);
    client
        .execute(&drop_query, &[])
        .await
        .expect("Failed to drop test database");

    println!("🧹 Cleaned up test database: {}", database_name);
}

pub struct TestApp {
    pub address: String,
    pub db_pool: Pool,
    _db: TestDatabase, // Keep database alive for the test duration
}

impl TestApp {
    pub async fn spawn() -> TestApp {
        use std::net::TcpListener;
        use std::sync::LazyLock;
        use zero2prod::{
            startup::run,
            telemetry::{get_subscriber, init_subscriber},
        };

        // Initialize tracing once
        static TRACING: LazyLock<()> = LazyLock::new(|| {
            let default_filter_level = "info".to_string();
            let subscriber_name = "test".to_string();
            if std::env::var("TEST_LOG").is_ok() {
                let subscriber =
                    get_subscriber(subscriber_name, default_filter_level, std::io::stdout);
                init_subscriber(subscriber);
            } else {
                let subscriber =
                    get_subscriber(subscriber_name, default_filter_level, std::io::sink);
                init_subscriber(subscriber);
            };
        });
        LazyLock::force(&TRACING);

        let configuration = get_configuration().expect("Failed to read configuration");
        // Setup test database
        let db = TestDatabase::new().await;

        // Build a new email client
        let sender_email = configuration
            .email_client
            .sender()
            .expect("Invalid sender email address.");

        let timeout = configuration.email_client.timeout();
        let email_client = EmailClient::new(
            configuration.email_client.base_url,
            sender_email,
            configuration.email_client.authorization_token,
            timeout,
        );

        // Setup application
        let listener = TcpListener::bind("127.0.0.1:0").expect("Failed to bind random port");
        let port = listener.local_addr().unwrap().port();

        // let server = run(listener, db.pool.clone(), email_client).expect("Failed to bind address");
        let application = Application::build(configuration.clone())
            .await
            .expect("Failed to build application");

        let address = format!("http://127.0.0.1:{}", application.port());
        let _ = tokio::spawn(application.run_until_stopped());

        TestApp {
            address,
            db_pool: db.pool.clone(),
            _db: db, // Database will be cleaned up when TestApp is dropped
        }
    }

    pub async fn post_subscriptions(&self, body: String) -> reqwest::Response {
        reqwest::Client::new()
            .post(&format!("{}/subscriptions", &self.address))
            .header("Content-Type", "application/x-www-form-urlencoded")
            .body(body)
            .send()
            .await
            .expect("Failed to execute request")
    }
}
