package com.project.template.mapper;

import com.project.template.model.PageResponse;
import com.project.template.model.UserResponse;
import com.project.template.persistence.view.UserView;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.springframework.data.domain.Page;

import java.util.List;

/**
 * @author Ouweshs28
 */
@Mapper(componentModel = "spring", uses = UserMapper.class)
public interface PageMapper {

    @Mapping(target = "content", expression = "java(toContent(result))")
    PageResponse toPageResponse(Page<UserView> result);

    default List<UserResponse> toContent(Page<UserView> result) {
        return result.getContent().stream().map(this::toUserResponse).toList();
    }

    UserResponse toUserResponse(UserView view);
}