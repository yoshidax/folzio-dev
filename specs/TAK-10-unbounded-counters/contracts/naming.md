# Naming contract

`uniqueName(for:existingNames:)` は `String` を返す既存 API を維持する。末尾の半角十進連番は桁数を問わず加算し、衝突がある限り繰り返す。拡張子と衝突照合の扱いは既存どおり。実際の作成時の OS エラーは呼び出し元が既存のエラーとして報告する。
