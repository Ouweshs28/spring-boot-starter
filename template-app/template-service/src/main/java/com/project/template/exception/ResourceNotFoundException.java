package com.project.template.exception;

/**
 * @author Ouweshs28
 */

public class ResourceNotFoundException extends RuntimeException {

    public ResourceNotFoundException(String message) {
        super(message);
    }

}