В папке приложение maonitoring_app тестировал в начале в doker
В файле make есть разворачивание и тестирование

Docker image used:
a1ekseyramblerru/monitoring-app:1.0

## Install everything
make install

## Run test
make k8s-test

## Run Helm test
make helm-test

## Remove all
make uninstall
