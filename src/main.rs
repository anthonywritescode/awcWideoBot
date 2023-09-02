use ed25519_dalek::Signature;
use ed25519_dalek::VerifyingKey;
use ed25519_dalek::PUBLIC_KEY_LENGTH;
use ed25519_dalek::SIGNATURE_LENGTH;
use lambda_http::http::{HeaderMap, HeaderValue};
use lambda_http::{run, service_fn, Body, Error, IntoResponse, Request, Response};
use std::env;
use std::path;

#[derive(serde::Deserialize)]
struct Playlists {
    playlists: Vec<Playlist>,
}

#[derive(serde::Deserialize)]
struct Playlist {
    playlist_name: String,
    videos: Vec<Video>,
}

fn init_db(path: &path::Path) -> anyhow::Result<()> {
    let conn = rusqlite::Connection::open(path)?;
    conn.execute(
        "CREATE VIRTUAL TABLE videos USING FTS5 (playlist, url, title)",
        (),
    )?;

    let playlists = ureq::get("https://anthonywritescode.github.io/explains/playlists.json")
        .call()?
        .into_json::<Playlists>()?
        .playlists;

    for playlist in playlists {
        for video in playlist.videos {
            conn.execute(
                "INSERT INTO videos VALUES (?, ?, ?)",
                (&playlist.playlist_name, &video.url, &video.title),
            )?;
        }
    }
    Ok(())
}

#[derive(serde::Deserialize, Debug)]
struct Video {
    title: String,
    url: String,
}

#[derive(serde::Deserialize)]
struct Param {
    value: String,
}

#[derive(serde::Deserialize)]
struct Data {
    name: String,
    options: Vec<Param>,
}

#[derive(serde::Deserialize)]
struct WebhookBody {
    data: Data,
}

#[derive(serde::Deserialize)]
struct WebhookType {
    #[serde(rename = "type")]
    webhook_type: u32,
}

fn is_ping(event: &Request) -> anyhow::Result<bool> {
    let s = std::str::from_utf8(event.body())?;
    let de = serde_json::from_str::<WebhookType>(s)?;
    Ok(de.webhook_type == 1)
}

struct Query {
    playlist: String,
    query: String,
}

fn query(event: &Request) -> anyhow::Result<Query> {
    let s = std::str::from_utf8(event.body())?;
    let de = serde_json::from_str::<WebhookBody>(s)?;
    Ok(Query {
        playlist: de.data.name,
        query: de.data.options[0].value.clone(),
    })
}

fn header<'a>(headers: &'a HeaderMap<HeaderValue>, s: &str) -> anyhow::Result<&'a HeaderValue> {
    headers.get(s).ok_or(anyhow::anyhow!("missing header: {s}"))
}

fn results(db_path: &path::Path, request: &Query) -> anyhow::Result<Vec<Video>> {
    let mut res = Vec::new();

    let db = rusqlite::Connection::open(db_path)?;
    let mut stmt = db.prepare(
        "SELECT url, title FROM videos WHERE playlist = ? AND title MATCH ? ORDER BY rank",
    )?;
    let rows = stmt.query_map((&request.playlist, &request.query), |row| {
        Ok(Video {
            url: row.get(0)?,
            title: row.get(1)?,
        })
    })?;

    for video in rows {
        res.push(video?);
    }

    Ok(res)
}

async fn handler(
    verifier: &VerifyingKey,
    db_path: &path::Path,
    event: Request,
) -> Result<impl IntoResponse, Error> {
    let headers = event.headers();

    let mut signature_buf: [u8; SIGNATURE_LENGTH] = [0; SIGNATURE_LENGTH];
    let signature_hex = header(headers, "x-signature-ed25519")?;
    hex::decode_to_slice(signature_hex, &mut signature_buf)?;
    let signature = Signature::from_bytes(&signature_buf);

    let mut body = Vec::<u8>::new();
    body.extend(header(headers, "x-signature-timestamp")?.as_bytes());
    match event.body() {
        Body::Text(s) => body.extend(s.as_bytes()),
        Body::Binary(b) => body.extend(b),
        _ => (),
    }
    verifier.verify_strict(&body, &signature)?;

    if is_ping(&event)? {
        let resp = Response::builder()
            .status(200)
            .header("content-type", "application/json")
            .body(serde_json::json!({"type": 1}).to_string())
            .map_err(Box::new)?;
        return Ok(resp);
    }

    let videos = results(db_path, &query(&event)?)?;
    let msg = match &videos[..] {
        [] => "no videos found".into(),
        [v0] => format!("{} - {}", v0.title, v0.url),
        [v0, v1] => format!("{} - {} & {} - {}", v0.title, v0.url, v1.title, v1.url),
        [v0, ..] => format!(
            "{} - {} & {} other videos found",
            v0.title,
            v0.url,
            videos.len()
        ),
    };

    let resp = Response::builder()
        .status(200)
        .header("content-type", "application/json")
        .body(
            serde_json::json!({
                "type": 4,
                "data": {
                    "tts": false,
                    "content": msg,
                    "embeds": [],
                    "allow_mentions": {"parse": []}
                }
            })
            .to_string(),
        )
        .map_err(Box::new)?;
    Ok(resp)
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    let (_, db_path) = tempfile::NamedTempFile::new()?.keep()?;
    init_db(&db_path)?;

    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .with_target(false)
        .without_time()
        .init();

    let mut key_buf: [u8; PUBLIC_KEY_LENGTH] = [0; PUBLIC_KEY_LENGTH];
    let key_hex = env::var("BOT_PUBLIC_KEY").unwrap();
    hex::decode_to_slice(&key_hex, &mut key_buf)?;
    let verifier = VerifyingKey::from_bytes(&key_buf)?;

    run(service_fn(|event: Request| async {
        handler(&verifier, &db_path, event).await
    }))
    .await
}
