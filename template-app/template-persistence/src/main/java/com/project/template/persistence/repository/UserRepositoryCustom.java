package com.project.template.persistence.repository;

import com.project.template.persistence.enumeration.GenderEnum;
import com.project.template.persistence.view.UserView;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

/**
 * Custom query methods for {@link com.project.template.persistence.entity.UserEntity}.
 *
 * @author Ouweshs28
 */
public interface UserRepositoryCustom {

    Page<UserView> findAll(String criteria, GenderEnum gender, Pageable pageable);
}
