package com.stehnik.tradebook;

import com.stehnik.tradebook.model.tables.Book;
import com.stehnik.tradebook.model.tables.Instrument;
import com.stehnik.tradebook.model.tables.Trade;
import com.stehnik.tradebook.model.tables.daos.PositionDao;
import com.stehnik.tradebook.model.tables.pojos.Position;
import org.jooq.Configuration;
import org.jooq.DSLContext;
import org.jooq.Result;
import org.jooq.impl.DSL;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

import static com.stehnik.tradebook.model.Tables.*;

/**
 * Beginnings of a REST service to present trade and position details
 */
@RestController
public class TradebookController {

    private final PositionDao positionDao;

    private final DSLContext dsl;

    public TradebookController(DSLContext dsl, Configuration jooqConfiguration) {
        this.positionDao = new PositionDao(jooqConfiguration);

        this.dsl = dsl;
    }

    @GetMapping("/listPositions")
    public List<Position> positions() {
        return this.positionDao.findAll();
    }

    /*
       Get the trades for given position (book/instrument)

       e.g. http://localhost:8080/tradesForPosition?book=US%20Eq%20Flow&security=TSLA

       will execute this sql:

       SELECT t.quantity,  t.id,  client_book.display_name
       from trade t,
       book trade_book,
       book client_book,
       instrument i
       where trade_book.id = t.portfolio_a
       and client_book.id = t.portfolio_b
       and t.instrument_id = i.id
       and trade_book.display_name = 'US Eq Flow'
       and i.name = 'TSLA'

     */
    @GetMapping("/tradesForPosition")
    public Object tradesForPosition(@RequestParam String book, @RequestParam String security) {
        Book trade_book = BOOK.as("trade_book");
        Book client_book = BOOK.as("client_book");
        return dsl.select()
                .from(TRADE)
                .join(trade_book).on(TRADE.PORTFOLIO_A.eq(trade_book.ID))
                .join(client_book).on(TRADE.PORTFOLIO_B.eq(client_book.ID))
                .join(INSTRUMENT).on(TRADE.INSTRUMENT_ID.eq(INSTRUMENT.ID))
                .where(trade_book.DISPLAY_NAME.eq(book))
                .and(INSTRUMENT.NAME.eq(security))
                .fetch()
                .into(TRADE.QUANTITY, TRADE.ID, client_book.DISPLAY_NAME)
                .intoArrays();
    }
}
