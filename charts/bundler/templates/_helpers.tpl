{{/*
Create the database URL environment variable for use by the bundler
*/}}
{{- define "bundler.databaseURL" -}}
{{- $raw_user_info := printf "%s:$BUNDLER_DATABASE_PASSWORD" .Values.bundler.database.user }}
{{- $raw_database_url := urlJoin (dict "scheme" .Values.bundler.database.scheme "host" .Values.bundler.database.host "path" .Values.bundler.database.path "userinfo" $raw_user_info ) }}
{{- replace "$BUNDLER_DATABASE_PASSWORD" "$(BUNDLER_DATABASE_PASSWORD)" $raw_database_url }}
{{- end }}
