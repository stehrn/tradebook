DROP TABLE IF EXISTS book;

CREATE TABLE book (
  id INT AUTO_INCREMENT  PRIMARY KEY,
  book_type VARCHAR(250) NOT NULL,
  denominated CHAR(3) NOT NULL,
  display_name VARCHAR(250) NOT NULL,
  description VARCHAR(250) NOT NULL,
  trader VARCHAR(250) NOT NULL,
  entity VARCHAR(250) NOT NULL
);


INSERT INTO book (book_type, denominated, display_name, description, trader, entity) VALUES
  ('Profit Centre', 'USD', 'ATEMK01', '', 'Nik Stehr', 'PSUS'),
  ('Profit Centre', 'GBP', 'ATFMK02', '', 'Mark Rogerson', 'PSEU'),
  ('Profit Centre', 'EUR', 'ATEMP03', '', 'Jenny Osmond', 'PSEU');

