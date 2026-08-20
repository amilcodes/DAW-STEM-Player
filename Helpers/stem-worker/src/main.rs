use serde_json::json;
use std::env;
use std::path::Path;
use std::process;
use std::sync::atomic::{AtomicU64, Ordering};
use stem_splitter_core::{
    set_download_progress_callback, set_split_progress_callback, split_file, SplitOptions,
    SplitProgress,
};

fn emit(progress: f64, message: &str) {
    println!("{}", json!({"progress": progress, "message": message}));
}

static DOWNLOAD_BUCKET: AtomicU64 = AtomicU64::new(u64::MAX);

fn main() {
    if let Err(error) = run() {
        eprintln!("{error}");
        process::exit(1);
    }
}

fn run() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 || args[1] != "split" {
        return Err("usage: stem-worker split --input <file> --output <directory>".into());
    }

    let input = argument(&args, "--input").ok_or("missing --input")?;
    let output = argument(&args, "--output").ok_or("missing --output")?;
    if !Path::new(&input).exists() {
        return Err(format!("input file not found: {input}").into());
    }
    std::fs::create_dir_all(&output)?;

    set_download_progress_callback(|downloaded, total| {
        let fraction = if total > 0 {
            downloaded as f64 / total as f64
        } else {
            0.0
        };
        let bucket = (fraction * 200.0).floor() as u64;
        if DOWNLOAD_BUCKET.swap(bucket, Ordering::Relaxed) != bucket {
            emit(fraction * 0.12, "Downloading the local separation model…");
        }
    });

    set_split_progress_callback(|progress| match progress {
        SplitProgress::Stage(stage) => {
            let (value, message) = match stage {
                "resolve_model" => (0.03, "Checking the separation model…"),
                "engine_preload" => (0.14, "Loading the separation engine…"),
                "read_audio" => (0.18, "Reading and conforming audio…"),
                "infer" => (0.22, "Separating drums, vocals, bass, and other…"),
                "write_stems" => (0.90, "Writing stem files…"),
                "finalize" => (0.98, "Finalizing the project…"),
                _ => (0.10, stage),
            };
            emit(value, message);
        }
        SplitProgress::Chunks { percent, .. } => {
            let percent = f64::from(percent);
            emit(0.22 + (percent / 100.0) * 0.67, "Separating audio locally…");
        }
        SplitProgress::Writing { stem, percent, .. } => {
            let percent = f64::from(percent);
            emit(0.90 + (percent / 100.0) * 0.08, &format!("Writing {stem}…"));
        }
        SplitProgress::Finished => emit(0.99, "Separation complete…"),
    });

    emit(0.01, "Starting local separation…");
    let result = split_file(
        &input,
        SplitOptions {
            output_dir: output,
            model_name: "htdemucs_ort_v1".to_string(),
            manifest_url_override: None,
        },
    )?;

    println!(
        "{}",
        json!({
            "progress": 1.0,
            "message": "Separation complete",
            "vocals": result.vocals_path,
            "drums": result.drums_path,
            "bass": result.bass_path,
            "other": result.other_path
        })
    );
    Ok(())
}

fn argument(args: &[String], name: &str) -> Option<String> {
    args.iter()
        .position(|value| value == name)
        .and_then(|index| args.get(index + 1))
        .cloned()
}

#[cfg(test)]
mod tests {
    use super::argument;

    #[test]
    fn extracts_named_argument() {
        let args = ["stem-worker", "split", "--input", "song.wav", "--output", "stems"]
            .map(str::to_string);
        assert_eq!(argument(&args, "--input").as_deref(), Some("song.wav"));
        assert_eq!(argument(&args, "--output").as_deref(), Some("stems"));
    }

    #[test]
    fn rejects_missing_argument_value() {
        let args = ["stem-worker", "split", "--input"].map(str::to_string);
        assert_eq!(argument(&args, "--input"), None);
        assert_eq!(argument(&args, "--output"), None);
    }
}
