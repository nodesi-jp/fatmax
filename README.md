# fatmax — apt リポジトリ

複数マシンで動く Claude Code CLI の状態・会話・コストを1画面に集約する、LAN 専用のダッシュボードです。

**ここにはバイナリと索引しか置いていません**（ソースは含みません）。

---

## 入れる

```sh
# 1. 署名鍵
curl -fsSL https://koujimorimoto-nodes.github.io/fatmax/KEY.gpg | sudo tee /usr/share/keyrings/fatmax.gpg > /dev/null

# 2. 取得先
echo "deb [signed-by=/usr/share/keyrings/fatmax.gpg] https://koujimorimoto-nodes.github.io/fatmax stable main" | sudo tee /etc/apt/sources.list.d/fatmax.list

# 3. 入れる
sudo apt update
sudo apt install fatmax      # 集約する1台だけ
```

署名済みです。

入れると `fatmax` が systemd のサービスとして起動し、`0.0.0.0:8787` で待ち受けます。

```sh
systemctl status fatmax
```

ブラウザで `http://<そのマシンの IP>:8787/` を開いてください。

## 見たいマシンを繋ぐ

**監視される側には何も置きません。** ハブの画面に出る1行を叩くだけです。

```sh
curl -fsSL http://<ハブの IP>:8787/setup.sh | sh
```

`~/.claude/settings.json` に hook と statusLine が入ります。抜くのも1コマンドです。

## 中継（任意）

ハブが落ちている間のイベントを溜め、実行中に差し込んだ指示も拾えるようになります。
入れなくても hook はハブへ直接届きます。

```sh
sudo apt install fatmax

# 送り先を書く（既定は自分自身なので、ハブが別マシンなら必須）
sudoedit /etc/fatmax/relay.conf        # HUB=http://192.168.0.19:8787

# 自分のユーザで起動する（root ではありません）
systemctl --user enable --now fatmax
loginctl enable-linger "$USER"               # ログアウト後も動かすなら
```

`~/.claude/projects` を読むため、**ユーザ単位のサービス**として動かします。

## 知っておくこと

- **認証はありません。** LAN 内で使う前提です。インターネットに出さないでください
- 記録は `/var/lib/fatmax/fatmax.db`（SQLite ファイル1個）。**アンインストールしても消しません**
- 集めるのは、会話の本文・ツールの実行記録・トークンとコスト・マシン名です。
  見られたくない会話があるマシンには入れないでください
- 対応は **amd64 のみ**です（arm64 はまだ作っていません）
- 版はビルド日時です。`fatmax --version` で確かめられます

## 中身

| パッケージ | 何をするか | どこに置くか |
|---|---|---|
| `fatmax` | 集約するハブ。UI と DB を内包 | 1台だけ |
| `fatmax` | hook の中継（任意） | 見たいマシンそれぞれ |

- 詳細: https://github.com/koujimorimoto-nodes/fatmax

---

Claude および Claude Code は Anthropic の商標です。本ソフトウェアは Anthropic とは無関係の
第三者製ツールで、Anthropic による承認・提供を受けたものではありません。
