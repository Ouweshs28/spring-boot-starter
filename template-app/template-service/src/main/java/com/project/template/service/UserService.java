package com.project.template.service;

import com.project.template.model.Gender;
import com.project.template.model.PageResponse;
import com.project.template.model.UserCreateUpdateRequest;
import com.project.template.model.UserResponse;
import com.project.template.persistence.entity.UserEntity;
import org.springframework.data.domain.PageRequest;

/**
 * @author Ouweshs28
 */
public interface UserService {

    Long createUser(UserCreateUpdateRequest createUserRequest);

    void updateUser(UserCreateUpdateRequest userUpdateRequest);

    void deleteUser(Long userId);

    UserResponse findUserById(Long userId);

    PageResponse findAllUsers(String criteria, Gender gender, PageRequest pageRequest);

    UserEntity findByUsername(String username);

}
