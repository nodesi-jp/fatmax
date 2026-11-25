# apt で入れる（Ubuntu / Debian）

Ubuntu・Debian（WSL の Ubuntu を含む）に **apt で入れる**手順です。いま配っているのは `0.1.159` です。
CPU（amd64 / arm64）は apt が選びます。署名済みです。

入れるものは1つ（`fatmax` パッケージ）で、**入れたマシンの役目は次のどちらか**です。

| 役目 | すること | 台数 |
|---|---|---|
| **ハブ** | 画面と記録を集める | **LAN に1台** |
| **見たいマシン** | そのマシンの Claude Code の記録をハブへ送る（ウォッチャー） | 何台でも |

1台でハブと見たいマシンを兼ねても構いません（下の「ハブのマシン自身も見る」）。

- dnf のディストリ（Amazon Linux / Fedora / RHEL） → **[dnf で入れる](INSTALL-dnf.md)**
- ハブを Docker で動かす → **[Docker で動かす](INSTALL-docker.md)**
- Windows → **[Windows で入れる](INSTALL-windows.md)**

## 1. パッケージを入れる（どちらの役目でも同じ）

```sh
curl -fsSL https://nodesi-jp.github.io/fatmax/KEY.gpg | sudo tee /usr/share/keyrings/fatmax.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/fatmax.gpg] https://nodesi-jp.github.io/fatmax stable main" | sudo tee /etc/apt/sources.list.d/fatmax.list
sudo apt update && sudo apt install fatmax
fatmax --version
```

**入れただけでは何も動きません。** 役目に合わせて 2. のどちらかへ進みます。

## 2a. ハブにする

```sh
sudo systemctl enable --now fatmax-hub
```

`http://<このマシンの IP>:8787/` が開けば動いています。記録は `/var/lib/fatmax/fatmax.db` です。

- **認証はありません。** LAN の外に出さないでください
- **ハブは LAN に1台だけ**にします。見たいだけのマシンでこの1行を叩くと、ハブがもう1つ立ちます
- ハブが配るウォッチャーの実行ファイルは、**このマシンと同じ CPU のぶんだけ**です。
  Mac や Windows も繋ぐなら、[Docker で動かしたハブ](INSTALL-docker.md)のほうが楽です（全部配れます）

## 2b. 見たいマシンにする

**Claude Code を開いているフォルダで**叩きます（入れ直しのときに二重登録を外せるのが、そのフォルダの下だけのため）。

```sh
# ハブに届くか
curl -fsS -m 5 -o /dev/null http://<ハブの IP>:8787/healthz && echo 届く

# hook・OTel・宛先を入れる（パッケージの fatmax をそのまま使う）
curl -fsSL http://<ハブの IP>:8787/setup.sh | sh

# ウォッチャーを動かす
nohup fatmax watch > /tmp/fatmax-watch.log 2>&1 &
fatmax status
```

終わったら **Claude Code を開き直してください**（OTel の設定は起動時にしか読まれません）。

- **ウォッチャーを動かさないと、記録はハブへ上がりません。** 消えはしません ——
  `~/.fatmax/spool` に溜まっていて、動かせばまとめて流れます
- **ウォッチャーはログアウト・再起動で止まります**（自分では立ち上がりません）。
  止まったら `nohup` の行を叩き直してください
- 画面に出る名前を決めるなら `echo '開発機' > ~/.claude/fatmax-host`（送るたびに読み直すので、再起動は要りません）
- 画面から返信したい・トークルームに本体で入れたいなら、`fatmax watch --replies` で動かします。
  **受けると、LAN の誰でもこのマシンの Claude に依頼を送れます**（ハブに認証が無いため）。
  詳しくは [画面から返信する](INSTALL.md#画面から返信する任意)

### ハブのマシン自身も見る

宛先を `127.0.0.1` にします。DHCP で IP が動いても外れません。

```sh
curl -fsSL http://127.0.0.1:8787/setup.sh | sh -s -- --hub http://127.0.0.1:8787
nohup fatmax watch > /tmp/fatmax-watch.log 2>&1 &
```

### sudo の無い root のコンテナ

devcontainer などで、プロンプトが `root@<英数字>:/workspaces#` の形のときです。**`sudo` を外す**のと、**名前を付ける**のが違いです。

```sh
curl -fsSL https://nodesi-jp.github.io/fatmax/KEY.gpg -o /usr/share/keyrings/fatmax.gpg
echo "deb [signed-by=/usr/share/keyrings/fatmax.gpg] https://nodesi-jp.github.io/fatmax stable main" > /etc/apt/sources.list.d/fatmax.list
apt update && apt install -y fatmax

mkdir -p ~/.claude && echo 'dev-linux' > ~/.claude/fatmax-host
curl -fsSL http://<ハブの IP>:8787/setup.sh | sh
nohup fatmax watch > /tmp/fatmax-watch.log 2>&1 &
```

- **名前を付けないと、コンテナを作り直すたびに別のマシンとして出ます**（hostname がコンテナの ID になるため）
- コンテナの中から、ホスト側で動いているハブへは `http://host.docker.internal:8787` で届きます
- 作り直す（Rebuild）と全部消えるので、もう一度叩いてください

## 新しい版に上げる

```sh
sudo apt update && sudo apt install --only-upgrade fatmax
fatmax --version
```

**入れ替わるのはファイルだけです。** 動いているものは前の版のままなので、動かし直します。

```sh
sudo systemctl restart fatmax-hub                                              # ハブ
pkill -f 'fatmax watch'; nohup fatmax watch > /tmp/fatmax-watch.log 2>&1 &     # 見たいマシン
fatmax status
```

動かし直し忘れていると、`fatmax status` が「再起動していません」と知らせます。
**ハブとウォッチャーの版は揃えてください**（片方だけ古いと、欠けた機能が黙って動きません）。

## 外す

見たいマシン（Claude Code を開いているフォルダで）:

```sh
curl -fsSL http://<ハブの IP>:8787/setup.sh | sh -s -- --uninstall
pkill -f 'fatmax watch'
```

`settings.json` から fatmax が入れたものだけを外します。あなた自身の設定は残ります。

パッケージごと外す:

```sh
sudo systemctl disable --now fatmax-hub     # ハブにしていたら
sudo apt purge fatmax
sudo rm /etc/apt/sources.list.d/fatmax.list /usr/share/keyrings/fatmax.gpg
```

**記録は消えません**（`purge` でも残します）。消すなら自分で `sudo rm -rf /var/lib/fatmax`。

---

[README に戻る](README.md) ／ [詳しい説明（install）](INSTALL.md)
