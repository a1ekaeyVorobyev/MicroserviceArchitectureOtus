package db

import (

    "github.com/jmoiron/sqlx"
    _ "github.com/lib/pq"
)

var DB *sqlx.DB

// SetDB устанавливает глобальную переменную DB
func SetDB(d *sqlx.DB) {
    DB = d
}
