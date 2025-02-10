use anyhow::Result;
use httpc_test;

#[tokio::test]
async fn test_main() -> Result<()> {
    let hc = httpc_test::new_client("http://localhost:3000")?;

    hc.do_get("/health/status?client_id=1234")
        .await?
        .print()
        .await?;

    Ok(())
}
