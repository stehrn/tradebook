-- schema

DROP TABLE IF EXISTS book;

CREATE TABLE book (
  id INT AUTO_INCREMENT  PRIMARY KEY,
  book_type VARCHAR(20) NOT NULL,
  denominated CHAR(3) NOT NULL,
  display_name VARCHAR(50) NOT NULL,
  trader VARCHAR(50) NULL,
  entity CHAR(4) NOT NULL
);

DROP TABLE IF EXISTS instrument;

CREATE TABLE instrument (
  id INT AUTO_INCREMENT  PRIMARY KEY,
  name VARCHAR(100) NOT NULL
);

DROP TABLE IF EXISTS trade;

CREATE TABLE trade (
  id INT AUTO_INCREMENT  PRIMARY KEY,
  portfolio_a INT NOT NULL,
  portfolio_b INT NOT NULL,
  trader VARCHAR(50),
  trade_type CHAR(1) NOT NULL,
  quantity INT NOT NULL,
  instrument_id INT NOT NULL,
  unit_price DECIMAL(10,5),
  unit_ccy CHAR(3) NOT NULL,
  FOREIGN KEY (portfolio_a) REFERENCES book(id),
  FOREIGN KEY (portfolio_b) REFERENCES book(id),
  FOREIGN KEY (instrument_id) REFERENCES instrument(id)
);

DROP TABLE IF EXISTS position;

CREATE TABLE position (
  id INT AUTO_INCREMENT  PRIMARY KEY,
  book_id INT NOT NULL,
  instrument_id  INT NOT NULL,
  quantity INT NOT NULL,
  FOREIGN KEY (book_id) REFERENCES book(id),
  FOREIGN KEY (instrument_id) REFERENCES instrument(id)
);

-- test data

INSERT INTO book (book_type, denominated, display_name, trader, entity) VALUES
  ('Profit Centre', 'GBP', 'ATEMK01', 'Nik Stehr', 'PSUS'),
  ('Profit Centre', 'GBP', 'ATFMK02', 'Mark Rogerson', 'PSEU'),
  ('Profit Centre', 'EUR', 'ATEMP03', 'Jenny Osmond', 'PSEU'),
  ('Client Book', 'GBP', 'Client A', null, 'JAAM'),
  ('Profit Centre', 'GBP', 'MKEIT01', 'Sammy Bruce', 'EUCE'),
  ('Client Book', 'GBP', 'Third Rock Investments', null, 'EUCE');

INSERT INTO instrument (name) VALUES
  ('XS0104440986'),
  ('XS0124569566'),
  ('XS0629974352'),
  ('XS0629974888'),
  ('TSLA');

INSERT INTO trade (portfolio_a, portfolio_b, trader, trade_type, quantity, instrument_id, unit_price, unit_ccy) VALUES
  (1, 4, '', 'B', 10, 3, 100.123, 'GBP'),
  (1, 4, '', 'S', 5, 3, 100.155, 'GBP'),
  (1, 4, '', 'B', 2, 3, 100.130, 'GBP'),
  (1, 4, '', 'B', 50, 1, 145.121, 'GBP'),
  (1, 4, '', 'S', 50, 1, 149.900, 'GBP'),
  (1, 4, '', 'B', 80, 2, 32.452, 'GBP'),
  (1, 4, '', 'S', 20, 2, 32.467, 'GBP'),
  (1, 4, '', 'B', 10, 4, 1003.1234, 'GBP'),
  (1, 4, '', 'B', 10, 4, 1003.1235, 'GBP'),
  (2, 4, '', 'B', 80, 4, 1003.10213, 'GBP');

INSERT INTO position (book_id, instrument_id, quantity) VALUES
(1, 3, 7),
(4, 3, -7),
(1, 1, 0),
(4, 1, 0),
(1, 2, 60),
(4, 2, -60),
(1, 4, 20),
(4, 4, -20),
(2, 4, 80),
(4, 4, -80),
(5, 5, 0),
(6, 5, 0);