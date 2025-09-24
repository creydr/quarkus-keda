package com.redhat.serverless.handler;

import org.slf4j.LoggerFactory;

public class Logger implements Handler{
    private static final org.slf4j.Logger logger = LoggerFactory.getLogger(Logger.class);

    @Override
    public void handle(String message) {
        // adding a bit of a lag
        try {
            Thread.sleep(10);
        } catch (InterruptedException e) {
            throw new RuntimeException(e);
        }

        logger.info("Received: {}", message);
    }
}
