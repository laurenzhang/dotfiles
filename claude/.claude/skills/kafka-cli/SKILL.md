---
name: kafka-cli
description: Reference for how Lauren authenticates and interacts with Kafka via the CLI
version: 1.0.0
---

# Kafka CLI Reference

If a `LOCAL.md` file exists next to this file, read it first. It holds the real bootstrap servers, where credentials come from, and environment-specific notes.

## Tools

- `kcat`: lightweight Kafka client for consuming, producing and listing metadata
- `kafka-topics`, `kafka-console-consumer` and the other standard Kafka CLI tools (`brew install kafka`)

## Config files

Credentials live in local config files, one per environment, outside any repository:

- `~/.config/kcat-<env>.conf`

Format:

```
bootstrap.servers=SASL_SSL://<bootstrap-host>:9092
security.protocol=SASL_SSL
sasl.mechanism=PLAIN
sasl.username=<api key>
sasl.password=<api secret>
```

Never print the contents of these files or commit them.

## General

Always print CLI commands on a single line. Multiline commands with `\` cause copy/paste problems.

## Using kcat

Pass the config file with `-F`:

```bash
kcat -F ~/.config/kcat-<env>.conf -L
kcat -F ~/.config/kcat-<env>.conf -L | grep <topic-filter>
kcat -F ~/.config/kcat-<env>.conf -C -t <topic> -o end
kcat -F ~/.config/kcat-<env>.conf -C -t <topic> -o -1 -e
```

The last command prints the final message and exits.

## Using kafka-topics and the other Kafka tools

Pass the config file with `--command-config`:

```bash
kafka-topics --bootstrap-server <bootstrap-host>:9092 --command-config ~/.config/kcat-<env>.conf --list
kafka-topics --bootstrap-server <bootstrap-host>:9092 --command-config ~/.config/kcat-<env>.conf --list --topic '<prefix>.*'
```
