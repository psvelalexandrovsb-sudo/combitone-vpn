# Combitone VPN — Windows desktop client (архитектура)

Flutter desktop-клиент. По сетевой части построен **1:1 с рабочим Android-клиентом**
(`combitone-android`): те же серверы, протоколы, ключи и логика выбора эндпоинта.
Отличие платформы: на Windows туннель поднимает **`sing-box.exe` напрямую** (TUN +
`auto_route`), без отдельного tun2socks-слоя.

## Поток подключения

```
Login (телефон+пароль) → AuthService → JWT
        ↓
fetchConfig(token) → VpnConfig (подписка с сервера, опционально содержит личный uuid)
        ↓
выбор VpnEndpoint (по умолчанию — Hysteria2/443) → _buildSingboxConfig()
        ↓
SingboxRunner.start(config) → sing-box.exe run -c <temp>.json
        ↓
ждём 1.5 с, проверяем что процесс жив → статус Connected / Error
```

## Ключевые файлы

| Файл | Назначение |
|------|-----------|
| `lib/models/vpn_endpoint.dart` | Список серверов (`kFallbackEndpoints`), перенесён 1:1 с Android: Hysteria2/443 (основной) + 6 VLESS+REALITY + 1 gRPC. Порядок = приоритет. |
| `lib/models/vpn_config.dart` | Подписка с сервера; геттер `uuid` извлекает личный UUID, иначе `kDefaultUuid`. |
| `lib/services/vpn_manager_windows.dart` | Состояние VPN, выбор эндпоинта (сохраняется в prefs), сборка конфига sing-box, авто-refresh подписки каждые 30 мин. |
| `lib/services/singbox_runner.dart` | Запуск/остановка `sing-box.exe`, перехват stdout/stderr в лог, проверка «живости». |
| `lib/services/logger.dart` | `AppLogger` — файловые логи (config + singbox.log) для диагностики, кнопка «Открыть логи». |
| `lib/screens/home_screen.dart` | UI: выпадающий список эндпоинтов, кнопка Connect, показ ошибки, кнопка логов. |

## Эндпоинты

- **Hysteria2 (UDP/QUIC, порт 443)** — основной. Проходит фильтрацию ТСПУ лучше VLESS+TCP.
- **6× VLESS+REALITY (TCP, Vision)** — запасные, разные порты/SNI/ключи.
- **1× VLESS+REALITY+gRPC** — мультиплекс (без `xtls-rprx-vision`, т.к. gRPC уже мультиплексирует).

Сервер один: `31.15.16.232`. UUID по умолчанию в `vpn_endpoint.dart`; если сервер
вернёт личный — используется он.

## sing-box config (важные нюансы Windows)

- **TUN stack = `gvisor`** (userspace). System-стек на Windows падает с
  *"lacked sufficient buffer space"* → трафик не идёт.
- **Маршрут к самому VPN-серверу (`server/32`) — `direct`**, плюс приватные подсети.
  Иначе `auto_route` заворачивает соединение sing-box→сервер обратно в туннель →
  маршрутная петля (100% CPU, нет трафика). Критично для UDP/Hysteria2.
- **`auto_detect_interface: true`** — выход прокси идёт через физический интерфейс,
  штатное решение петли `auto_route`.
- **Split-tunnel** по `process_name` (exe из списка исключений идут мимо VPN).

## Требования к запуску

- Нужны **права администратора (UAC)** — sing-box TUN требует elevation.
  Манифест в CI помечает .exe как `requireAdministrator`.
- `sing-box.exe` ищется рядом с .exe приложения, затем в PATH.

## Сборка

Локально из WSL Windows-десктоп не собирается. Сборка — через GitHub Actions
workflow **«Build Windows App»** (репо `psvelalexandrovsb-sudo/combitone-vpn`,
ветка `master`); .exe доступен в артефактах прогона.

## Диагностика

Если жмёшь Connect и статус «Ошибка» — кнопка **«Открыть логи»**: там `singbox.log`
(stdout/stderr процесса) и сохранённый config. Раньше клиент показывал ложное
«Подключено», даже когда sing-box падал сразу; теперь статус честный (ждём 1.5 с).
