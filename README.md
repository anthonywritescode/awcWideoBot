# awcWideoBot
a discord bot to search and grab wideo url's from a playlist.

### building

```bash
pip install ziglang
cargo install cargo-lambda
cargo-lambda build --release --output-format zip
```

### updating

```bash
aws lambda update-function-code --function-name awc_wideo_bot --zip fileb://target/lambda/awc-wideo-bot/bootstrap.zip
```
