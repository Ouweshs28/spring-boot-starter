package com.project.template.config;

import org.springdoc.core.configuration.SpringDocConfiguration;
import org.springdoc.core.properties.SpringDocConfigProperties;
import org.springdoc.core.providers.ObjectMapperProvider;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.context.annotation.Bean;

/**
 * @author Ouweshs28
 */
@AutoConfiguration
public class SpringDocsConfiguration {

    @Bean
    @ConditionalOnMissingBean
    SpringDocConfiguration springDocConfiguration() {
        return new SpringDocConfiguration();
    }

    @Bean
    @ConditionalOnMissingBean
    SpringDocConfigProperties springDocConfigProperties() {
        return new SpringDocConfigProperties();
    }

    @Bean
    @ConditionalOnMissingBean
    ObjectMapperProvider objectMapperProvider(SpringDocConfigProperties springDocConfigProperties) {
        return new ObjectMapperProvider(springDocConfigProperties);
    }

}
