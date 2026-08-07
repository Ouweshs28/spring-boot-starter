package com.project.template.persistence.repository;

import com.project.template.persistence.entity.UserEntity;
import org.springframework.stereotype.Repository;

/**
 * @author Ouweshs28
 */
@Repository
public interface UserRepository extends AbstractRepository<UserEntity>, UserRepositoryCustom {

}
