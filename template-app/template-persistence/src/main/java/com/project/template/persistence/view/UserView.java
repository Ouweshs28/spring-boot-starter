package com.project.template.persistence.view;

import com.blazebit.persistence.view.EntityView;
import com.blazebit.persistence.view.IdMapping;
import com.project.template.persistence.entity.UserEntity;
import com.project.template.persistence.enumeration.GenderEnum;

/**
 * Blaze-Persistence Entity View for UserEntity.
 * Excludes sensitive fields like password.
 *
 * @author Ouweshs28
 */
@EntityView(UserEntity.class)
public interface UserView {

    @IdMapping
    Long getId();

    String getUsername();

    String getEmail();

    String getFirstName();

    String getLastName();

    GenderEnum getGender();
}
