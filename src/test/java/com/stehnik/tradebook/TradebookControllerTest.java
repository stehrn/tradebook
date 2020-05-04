package com.stehnik.tradebook;

import org.junit.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.web.server.LocalServerPort;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
public class TradebookControllerTest  {

    @LocalServerPort
    private int port;

    @Autowired
    private TestRestTemplate restTemplate;

    /**
     * Test GET /listPositions
     */
    @Test
    public void listPositions()  {
        assertThat(this.restTemplate.getForObject("http://localhost:" + port + "/listPositions",
                Object.class)).isEqualTo("[" +
                "{\"bookId\":5,\"instrumentId\":8,\"quantity\":300}," +
                "{\"bookId\":6,\"instrumentId\":8,\"quantity\":-50}," +
                "{\"bookId\":4,\"instrumentId\":8,\"quantity\":-200}," +
                "{\"bookId\":1,\"instrumentId\":3,\"quantity\":7}," +
                "{\"bookId\":4,\"instrumentId\":3,\"quantity\":-7}," +
                "{\"bookId\":1,\"instrumentId\":1,\"quantity\":0}," +
                "{\"bookId\":4,\"instrumentId\":1,\"quantity\":0}," +
                "{\"bookId\":1,\"instrumentId\":2,\"quantity\":60}," +
                "{\"bookId\":4,\"instrumentId\":2,\"quantity\":-60}," +
                "{\"bookId\":1,\"instrumentId\":4,\"quantity\":20}," +
                "{\"bookId\":4,\"instrumentId\":4,\"quantity\":-100}," +
                "{\"bookId\":2,\"instrumentId\":4,\"quantity\":80}," +
                "{\"bookId\":5,\"instrumentId\":5,\"quantity\":0}," +
                "{\"bookId\":6,\"instrumentId\":5,\"quantity\":0}" +
                "]");
    }
}