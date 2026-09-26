# Prizrak-Box (Pandora/Clash) — заметки по MCP-серверу

API Mihomo/clash-meta: `http://127.0.0.1:9686`, заголовок `Authorization: Bearer 17Rse39Dmvb4qpbu`.
Тулзы MCP: `prizrak_status`, `list_proxies(group)`, `select_proxy(group,name)`, `get_rules()`.

## TUN — включение/выключение

Включается динамически без перезапуска (PATCH меняет только вложенное поле):

```bash
# ВКЛЮЧИТЬ
curl -s -X PATCH -H "Authorization: Bearer 17Rse39Dmvb4qpbu" \
     -d '{"tun":{"enable":true}}' http://127.0.0.1:9686/configs   # -> 204

# ВЫКЛЮЧИТЬ
curl -s -X PATCH -H "Authorization: Bearer 17Rse39Dmvb4qpbu" \
     -d '{"tun":{"enable":false}}' http://127.0.0.1:9686/configs   # -> 204
```

Проверка: `prizrak_status()` → поле `tun_enable`. Живой интерфейс:
`ip -br addr | grep Prizrak` (Prizrak, 198.18.0.1/30). Логи: `/home/voron/Prizrak-Box-V3/logs/px-server.log`
(строка `[TUN] Tun adapter listening at: ...`).

### Требуемое условие — CAP_NET_ADMIN

Процесс `px` (`/usr/lib/prizrak-box/resources/px`) без права создания TAP падает с
`Start TUN listening error: configure tun interface: operation not permitted`.

Одноразовый фикс (обратимо):

```bash
sudo setcap cap_net_admin+ep /usr/lib/prizrak-box/resources/px   # выдать
# перезапуск px (Electron-клиент сам НЕ пересоздаёт процесс, только через UI):
kill $(pgrep -f 'resources/px')
nohup /usr/lib/prizrak-box/resources/px \
     -addr=127.0.0.1:44251 -home=%2Fhome%2Fvoron%2FPrizrak-Box-V3 &

sudo setcap -r /usr/lib/prizrak-box/resources/px                  # откат
```

После выдачи capability TUN поднимается сразу; при выключении интерфейс Prizrak убивается.

### Нюансы

- `PUT /configs` с JSON — не работает (ищет файл `config.yaml` в cwd px); только PATCH с частичным телом.
- Тело `{"enable":true}` без ключа `tun` при PATCH не применяется (204, но ничего не меняется).
- `prizrak_status()` читает `tun.enable` из живого `/configs`, т.е. отражает реальное состояние после PATCH.
