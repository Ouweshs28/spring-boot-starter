package com.project.template.rest;


import com.project.template.api.UserApi;
import com.project.template.model.Gender;
import com.project.template.model.PageResponse;
import com.project.template.model.UserCreateUpdateRequest;
import com.project.template.model.UserResponse;
import com.project.template.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RestController;

import static org.springframework.data.domain.Sort.Direction.ASC;
import static org.springframework.data.domain.Sort.Direction.DESC;

/**
 * @author Ouweshs28
 */
@RestController
@RequiredArgsConstructor
public class UserController implements UserApi {

    private final UserService userService;

    @Override
    public ResponseEntity<Long> createUser(UserCreateUpdateRequest userCreateRequest) {
        Long createdUserId = userService.createUser(userCreateRequest);
        return ResponseEntity.ok(createdUserId);
    }

    @Override
    public ResponseEntity<Void> deleteUser(Long userId) {
        userService.deleteUser(userId);
        return ResponseEntity.ok().build();
    }

    @Override
    public ResponseEntity<Void> updateUser(UserCreateUpdateRequest userUpdateRequest) {
        userService.updateUser(userUpdateRequest);
        return ResponseEntity.ok().build();
    }

    @Override
    public ResponseEntity<UserResponse> findUserById(Long userId) {
        return ResponseEntity.ok(userService.findUserById(userId));
    }


    @Override
    public ResponseEntity<PageResponse> findAllUsers(String criteria, Gender gender, Integer pageNumber, Integer pageSize, String sortOrder, String sortBy) {
        Sort sort = Sort.by("DESC".equalsIgnoreCase(sortOrder) ? DESC : ASC, sortBy == null ? "firstName" : sortBy);
        PageRequest pageRequest = PageRequest.of(pageNumber, pageSize, sort);
        return ResponseEntity.ok(userService.findAllUsers(criteria, gender, pageRequest));
    }
}