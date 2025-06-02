#[tokio::test]
async fn subscribe_returns_a_200_for_valid_form_data() {
    // Arrange
    let app = TestApp::spawn().await;
    let client = reqwest::Client::new();

    // Act
    let body = "name=le%20guin&email=ursula_le_guin%40gmail.com";
    let response = app.post_subscriptions(body.into());

    // Assert
    assert_eq!(200, response.status().as_u16());

    // Verify data was saved
    let client = app.db_pool.get().await.expect("Failed to get client");
    let rows = client
        .query("SELECT email, name FROM subscriptions", &[])
        .await
        .expect("Failed to fetch saved subscription.");

    let saved = &rows[0];
    assert_eq!("ursula_le_guin@gmail.com", saved.get::<_, String>("email"));
    assert_eq!("le guin", saved.get::<_, String>("name"));
}

#[tokio::test]
async fn subscribe_returns_a_400_when_data_is_missing() {
    // Arrange
    let app = TestApp::spawn().await;
    let client = reqwest::Client::new();
    let test_cases = vec![
        ("name=le%20guin", "missing the email"),
        ("email=ursula_le_guin%40gmail.com", "missing the name"),
        ("", "missing both name and email"),
    ];

    for (invalid_body, error_message) in test_cases {
        // Act
        let response = app.post_subscriptions(invalid_body.into());

        // Assert
        assert_eq!(
            400,
            response.status().as_u16(),
            "The API did not fail with 400 Bad Request when the payload was {}.",
            error_message
        );
    }
}

#[tokio::test]
async fn subscribe_returns_400_when_fields_are_present_but_empty() {
    // Arrange
    let app = TestApp::spawn().await;
    let client = reqwest::Client::new();

    let test_cases = vec![
        ("name=&email=ursula_le_guin%40gmail.com", "empty name"),
        ("name=Ursula&email=", "empty email"),
        ("name=Ursula&email=definitely-not-an-email", "invalid email"),
    ];

    for (body, description) in test_cases {
        //act
        let response = app.post_subscriptions(body.into());
        // assert
        assert_eq!(
            400,
            response.status().as_u16(),
            "The API did not return a 400 OK when the payload was {}.",
            description
        )
    }
}
