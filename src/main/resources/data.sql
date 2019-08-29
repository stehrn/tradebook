DROP TABLE IF EXISTS book;

CREATE TABLE book (
  id INT AUTO_INCREMENT  PRIMARY KEY,
  book_type VARCHAR(20) NOT NULL,
  denominated CHAR(3) NOT NULL,
  display_name VARCHAR(250) NOT NULL,
  trader VARCHAR(50) NULL,
  entity CHAR(4) NOT NULL
);

INSERT INTO book (book_type, denominated, display_name, trader, entity) VALUES
  ('Profit Centre', 'GBP', 'ATEMK01', 'Nik Stehr', 'PSUS'),
  ('Profit Centre', 'GBP', 'ATFMK02', 'Mark Rogerson', 'PSEU'),
  ('Profit Centre', 'EUR', 'ATEMP03', 'Jenny Osmond', 'PSEU'),
  ('Client Book', 'GBP', 'Client A', null, 'JAAM');

DROP TABLE IF EXISTS instrument;

CREATE TABLE instrument (
  id INT AUTO_INCREMENT  PRIMARY KEY,
  name VARCHAR(250) NOT NULL
);

INSERT INTO instrument (name) VALUES
  ('XS0104440986'),
  ('XS0124569566'),
  ('XS0629974352'),
  ('XS0629974888');

DROP TABLE IF EXISTS trade;

CREATE TABLE trade (
  id INT AUTO_INCREMENT  PRIMARY KEY,
  portfolio_a INT NOT NULL,
  portfolio_b INT NOT NULL,
  instrument_id  INT NOT NULL,
  trade_type CHAR(1) NOT NULL,
  quantity INT NOT NULL,
);


INSERT INTO trade (portfolio_a, portfolio_b, instrument_id, trade_type, quantity) VALUES
  (1, 4, 3, 'B', 10),
  (1, 4, 3, 'S', -5),
  (1, 4, 3, 'B', 2),
  (1, 4, 1, 'B', 50),
  (1, 4, 1, 'S', -50),
  (1, 4, 2, 'B', 50),
  (1, 4, 2, 'S', -62),
  (1, 4, 4, 'B', 1),
  (1, 4, 4, 'B', 1),
  (2, 4, 4, 'B', 8);

DROP TABLE IF EXISTS position;

CREATE TABLE position (
  id INT AUTO_INCREMENT  PRIMARY KEY,
  book_id INT NOT NULL,
  instrument_id  INT NOT NULL,
  denominated CHAR(3) NOT NULL
);

INSERT INTO position (book_id, instrument_id, denominated) VALUES
  (1, 1, 'GBP'),
  (1, 3, 'GBP'),
  (1, 2, 'GBP'),
  (1, 4, 'GBP'),
  (2, 4, 'GBP');
