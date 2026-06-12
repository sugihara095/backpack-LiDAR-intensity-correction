# backpack-LiDAR-intensity-correction

バックパック型LiDAR（Ouster）で取得した点群データ（PCD）に対する一連の処理（フィールド復元、法線推定、角度・距離計算、反射強度補正、リングフィルタリング）を自動で一括実行するための統合パイプラインリポジトリです。

## リポジトリの内容

* **`process_pipeline.sh`**: PCD処理パイプラインを実行するメインのシェルスクリプトです。各工程のROS 2パッケージを順番に呼び出し、一連の処理を自動化します。
* **`backpack_dependencies.repos`**: 本パイプラインを実行するために必要なROS 2パッケージ（依存関係）のリストです。`vcs` (vcstool) を使って関連パッケージを一括でクローンするために使用します。

---

## 🛠️ 環境構築と依存パッケージのインストール

本パイプラインはROS 2環境上で動作します。必要なパッケージは `backpack_dependencies.repos` に定義されており、以下の手順で一括ダウンロード・ビルドを行います。

### 1. リポジトリのクローンと依存関係の取得

ワークスペースの `src` ディレクトリ等の構成に合わせて依存パッケージをクローンします。（※本リポジトリ自体がワークスペース直下に置かれている場合は、以下のパスを適宜読み替えてください）

```bash
# 依存パッケージの一括ダウンロード
vcs import < backpack_dependencies.repos
```

### 2. ビルド

```bash
# ワークスペースのルートディレクトリで実行
colcon build --symlink-install
source install/setup.bash
```

---

## パイプラインの実行方法

### 1. 入力データの配置

スクリプトは `/home/hideki/pcdmap` ディレクトリ以下の特定のディレクトリ構造を前提としています。
実行前に、入力となる2つのPCDファイル（`result_pcd_1` および `result_pcd_2`）を以下の構成で配置してください。

```text
/home/hideki/pcdmap/
├── result_pcd_1/
│   └── <condition_name>/
│       └── <condition_name>_<timestamp_suffix>_1.pcd
└── result_pcd_2/
    └── <condition_name>/
        └── <condition_name>_<timestamp_suffix>_2.pcd
```

### 2. スクリプトの実行

パイプラインスクリプト `process_pipeline.sh` は、**条件名**と**タイムスタンプ（サフィックス）**の2つの引数を受け取ります。

```bash
# 実行権限を付与（初回のみ）
chmod +x process_pipeline.sh

# 実行
./process_pipeline.sh <condition_name> <timestamp_suffix>
```

**【実行例】**
```bash
./process_pipeline.sh parking_maruike_dry 20260118_2152
```

このコマンドを実行すると、以下の入力ファイルが自動的に読み込まれます。
* `/home/hideki/pcdmap/result_pcd_1/parking_maruike_dry/parking_maruike_dry_20260118_2152_1.pcd`
* `/home/hideki/pcdmap/result_pcd_2/parking_maruike_dry/parking_maruike_dry_20260118_2152_2.pcd`

### 3. 出力データ

パイプラインが完了すると、工程ごとの中間ファイルが生成され、最終的な補正・フィルタリング済みPCDファイルが `result_pcd_7` に出力されます。

* **最終出力**: `/home/hideki/pcdmap/result_pcd_7/<condition_name>/<condition_name>_<timestamp_suffix>_7.pcd`

---

## 処理パイプラインの概要

`process_pipeline.sh` は、以下の5つの工程を順次実行します。
※ 各工程のアルゴリズムや詳細なパラメータ設定については、それぞれの依存パッケージのリポジトリを参照してください。

1. **Field Restoration** (`pcd_field_restorer`)
   * 2つの入力PCDファイルから必要なフィールド情報を統合し、後続処理に必要なPCDデータを復元します（`result_pcd_3` を出力）。
2. **Cylinder Normal Estimation** (`ouster_cylinder_normal_estimator`)
   * 点群の形状から、センサー中心を軸とする円柱座標系における法線ベクトルを推定します（`result_pcd_4` を出力）。
3. **Angle and Distance Calculation**
   * 各点に対するセンサーからの距離と入射角を計算し、PCDファイルに情報を付与します（`result_pcd_5` を出力）。
4. **Intensity Correction** (`ouster_intensity_corrector`)
   * 推定した法線や距離・角度情報を用いて、LiDARの反射強度（Intensity）の補正を行います（`result_pcd_6` を出力）。
5. **Ring Filtering** (`ouster_ring_filter`)
   * スクリプト内で指定された特定のリング（例: `[8,9,10,11,12,13,14,15]`）の点群のみを抽出するフィルタリングを行います（`result_pcd_7` を出力）。
