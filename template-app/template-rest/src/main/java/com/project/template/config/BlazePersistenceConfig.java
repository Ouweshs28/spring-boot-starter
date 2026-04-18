package com.project.template.config;

import com.blazebit.persistence.Criteria;
import com.blazebit.persistence.CriteriaBuilderFactory;
import com.blazebit.persistence.integration.view.spring.EnableEntityViews;
import com.blazebit.persistence.spi.CriteriaBuilderConfiguration;
import com.blazebit.persistence.view.EntityViewManager;
import com.blazebit.persistence.view.spi.EntityViewConfiguration;
import jakarta.persistence.EntityManagerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * @author Ouweshs28
 */
@Configuration
@EnableEntityViews("com.project.template.persistence.view")
public class BlazePersistenceConfig {

    @Bean
    public CriteriaBuilderFactory criteriaBuilderFactory(EntityManagerFactory emf) {
        CriteriaBuilderConfiguration config = Criteria.getDefault();
        return config.createCriteriaBuilderFactory(emf);
    }

    @Bean
    public EntityViewManager entityViewManager(CriteriaBuilderFactory cbf,
                                               EntityViewConfiguration evc) {
        return evc.createEntityViewManager(cbf);
    }
}
