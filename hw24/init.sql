-- Создание таблицы для уведомлений
CREATE TABLE IF NOT EXISTS notifications (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL,
    email VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'sent'
);

-- Создание индекса для быстрого поиска по user_id
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);

-- Добавление комментариев
COMMENT ON TABLE notifications IS 'Хранилище уведомлений пользователей';
COMMENT ON COLUMN notifications.id IS 'Уникальный идентификатор уведомления';
COMMENT ON COLUMN notifications.user_id IS 'ID пользователя';
COMMENT ON COLUMN notifications.email IS 'Email получателя';
COMMENT ON COLUMN notifications.message IS 'Текст уведомления';
COMMENT ON COLUMN notifications.created_at IS 'Время создания';
COMMENT ON COLUMN notifications.status IS 'Статус отправки';

-- Создание тестовых данных (опционально)
INSERT INTO notifications (user_id, email, message, status) VALUES 
('test123', 'test@example.com', 'Тестовое уведомление 1', 'sent'),
('test123', 'test@example.com', 'Тестовое уведомление 2', 'sent');