use anyhow::Result;

#[tokio::test]
async fn test_main() -> Result<()> {
    use httpc_test;

    let hc = httpc_test::new_client("http://localhost:3000")?;

    hc.do_get("/health/status?client_id=1234")
        .await?
        .print()
        .await?;

    Ok(())
}

#[tokio::test]
async fn test_oauth2_token() -> Result<()> {
    let client = reqwest::Client::new();
    let params = [
        ("grant_type", "authorization_code"),
        ("redirect_uri", "https://donation-app.test/callback"),
        ("code", "ory_ac_afQ9jrgkI0Qiv7n5mMj3OoZMwFN-sv68q9C4p2eVnZw.aB9Ld1IdzxalT1grLwgWlSUkwAgkGaB5GOD6Q5H8GZ0"),
        ("code_verifier", "287f122bb75f465fa046291571db09f71a5c34b17938404e8f58e5a71dedca066e9091da85d848dd99e496fdaab9f5a3"),
        ("client_id", "frontend-client"),
    ];

    let response = client
        .post("http://localhost:3000/oauth2_token")
        .form(&params)
        .send()
        .await?;

    println!("Status: {:?}", response.status());
    println!("Body: {:?}", response.text().await?);

    Ok(())
}
