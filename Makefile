.PHONY: app helper test clean

app: helper
	./Scripts/build-app.sh

helper:
	cargo build --release --manifest-path Helpers/stem-worker/Cargo.toml

test:
	cargo test --release --manifest-path Helpers/stem-worker/Cargo.toml
	./Scripts/test-core.sh

clean:
	swift package clean
	cargo clean --manifest-path Helpers/stem-worker/Cargo.toml
