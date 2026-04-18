
package com.project.template.service.impl;

import com.project.template.exception.ResourceNotFoundException;
import com.project.template.mapper.PageMapper;
import com.project.template.mapper.UserMapper;
import com.project.template.model.Gender;
import com.project.template.model.PageResponse;
import com.project.template.model.UserCreateUpdateRequest;
import com.project.template.model.UserResponse;
import com.project.template.persistence.entity.UserEntity;
import com.project.template.persistence.repository.UserRepository;
import com.project.template.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;


/**
 * @author Ouweshs28
 */
@Service
@Transactional
@RequiredArgsConstructor
public class UserServiceImpl implements UserService {

    private static final String USER_ID_NOT_FOUND = "UserId :%d not found";

    private final UserRepository userRepository;
    private final UserMapper userMapper;
    private final PageMapper pageMapper;

    @Override
    public Long createUser(UserCreateUpdateRequest createUserRequest) {
        return userRepository.save(userMapper.mapToUserEntity(createUserRequest)).getId();
    }

    @Override
    public void updateUser(UserCreateUpdateRequest userUpdateRequest) {
        UserEntity user = userRepository.findById(userUpdateRequest.getId())
                .orElseThrow(() -> new ResourceNotFoundException(USER_ID_NOT_FOUND.formatted(userUpdateRequest.getId())));
        userMapper.mapToUpdateUserEntity(user, userUpdateRequest);
        userRepository.save(user);
    }

    @Override
    public void deleteUser(Long userId) {
        userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException(USER_ID_NOT_FOUND.formatted(userId)));
        userRepository.deleteById(userId);
    }

    @Override
    public UserResponse findUserById(Long userId) {
        return userRepository.findById(userId).map(userMapper::mapToUserResponse)
                .orElseThrow(() -> new ResourceNotFoundException(USER_ID_NOT_FOUND.formatted(userId)));
    }

    @Override
    public PageResponse findAllUsers(String criteria, Gender gender, PageRequest pageRequest) {
        return pageMapper.toPageResponse(userRepository.findAll(criteria, userMapper.toGenderEnum(gender), pageRequest));
    }

    @Override
    public UserEntity findByUsername(String username) {
        return userRepository.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("Username :%s not found".formatted(username)));
    }

}