# nefmon-log-client
Tools for setting up servers to send logs to nefmon.

ansibleディレクトリ内のplaybookを実行すると、以下のツールがインストールされます。
* td-agent
* god

## 対象サーバ上で既にtd-agentを使用している場合の注意
そのままansibleを実行すると/etc/td-agent/td-agent.confが上書きされるのでご注意ください。  
(backup=yesにしてあるので、間違って流しても元のファイルはリネームされて残ります)

この場合、multiprocessプラグインを利用してtd-agentを複数プロセス起動します。  
roles/td-agent/tasksの```Set conf file (single)```をコメントアウトし、  
```Set conf file (multi) 1```と```Set conf file (multi) 2```をコメントイン。  
roles/td-agent/templates/td-agent-multi.confを適宜編集してから実行してください。
