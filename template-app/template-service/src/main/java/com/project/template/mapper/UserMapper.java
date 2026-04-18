package com.project.template.mapper;

import com.project.template.model.Gender;
import com.project.template.model.UserCreateUpdateRequest;
import com.project.template.model.UserResponse;
import com.project.template.persistence.entity.UserEntity;
import com.project.template.persistence.enumeration.GenderEnum;
import com.project.template.persistence.view.UserView;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingTarget;
import org.mapstruct.ValueMapping;

/**
 * @author Ouweshs28
 */
@Mapper(componentModel = "spring")
public interface UserMapper {

    @Mapping(target = "id", ignore = true)
    UserEntity mapToUserEntity(UserCreateUpdateRequest createUserRequest);

    UserCreateUpdateRequest mapToUserCreateOrUpdateRequest(UserEntity user);

    UserResponse mapToUserResponse(UserEntity user);

    UserResponse mapToUserResponse(UserView userView);

    void mapToUpdateUserEntity(@MappingTarget UserEntity user, UserCreateUpdateRequest userUpdateRequest);

    @ValueMapping(source = "MALE", target = "MALE")
    @ValueMapping(source = "FEMALE", target = "FEMALE")
    GenderEnum toGenderEnum(Gender gender);

}