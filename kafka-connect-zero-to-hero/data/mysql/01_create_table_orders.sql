use root;

create table ORDERS (
	id MEDIUMINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
	customer_id INT,
	order_total_usd DECIMAL(11,2),
	make VARCHAR(50),
	model VARCHAR(50),
	delivery_city VARCHAR(50),
	delivery_company VARCHAR(50),
	delivery_address VARCHAR(50),
	CREATE_TS TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	UPDATE_TS TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
