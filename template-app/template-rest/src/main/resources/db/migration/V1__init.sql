-- ============================================================
-- V1 - Initial schema
-- ============================================================

CREATE TABLE next_stock_user
(
    id         BIGINT AUTO_INCREMENT NOT NULL,
    username   VARCHAR(255),
    email      VARCHAR(255),
    first_name VARCHAR(255),
    last_name  VARCHAR(255),
    gender     VARCHAR(50),
    created_on TIMESTAMP,
    updated_on TIMESTAMP,
    CONSTRAINT pk_next_stock_user PRIMARY KEY (id)
);
