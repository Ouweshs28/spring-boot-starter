package com.project.template.persistence.repository;

import com.blazebit.persistence.CriteriaBuilder;
import com.blazebit.persistence.CriteriaBuilderFactory;
import com.blazebit.persistence.PagedList;
import com.blazebit.persistence.PaginatedCriteriaBuilder;
import com.blazebit.persistence.view.EntityViewManager;
import com.blazebit.persistence.view.EntityViewSetting;
import com.project.template.persistence.entity.UserEntity;
import com.project.template.persistence.enumeration.GenderEnum;
import com.project.template.persistence.view.UserView;
import com.project.template.persistence.view.UserView_;
import jakarta.persistence.EntityManager;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Repository;

/**
 * @author Ouweshs28
 */
@Repository
@RequiredArgsConstructor
public class UserRepositoryCustomImpl implements UserRepositoryCustom {

    private final CriteriaBuilderFactory criteriaBuilderFactory;
    private final EntityViewManager entityViewManager;
    private final EntityManager entityManager;

    @Override
    public Page<UserView> findAll(String criteria, GenderEnum gender, Pageable pageable) {
        CriteriaBuilder<UserEntity> cb = criteriaBuilderFactory.create(entityManager, UserEntity.class);

        applyCriteriaFilter(cb, criteria);
        applyGenderFilter(cb, gender);
        applySort(cb, pageable.getSort());

        EntityViewSetting<UserView, PaginatedCriteriaBuilder<UserView>> setting =
                EntityViewSetting.create(UserView.class, (int) pageable.getOffset(), pageable.getPageSize());

        PagedList<UserView> resultList = entityViewManager
                .applySetting(setting, cb)
                .getResultList();

        return new PageImpl<>(resultList, pageable, resultList.getTotalSize());
    }

    private void applyCriteriaFilter(CriteriaBuilder<UserEntity> cb, String criteria) {
        if (criteria == null || criteria.isBlank()) return;

        String pattern = "%" + criteria.toLowerCase() + "%";
        cb.whereOr()
                .where("LOWER(firstName)").like().value(pattern).noEscape()
                .where("LOWER(lastName)").like().value(pattern).noEscape()
                .where("LOWER(username)").like().value(pattern).noEscape()
                .where("LOWER(email)").like().value(pattern).noEscape()
                .endOr();
    }

    private void applyGenderFilter(CriteriaBuilder<UserEntity> cb, GenderEnum gender) {
        if (gender == null) return;

        cb.where("gender").eq(gender);
    }

    private void applySort(CriteriaBuilder<UserEntity> cb, Sort sort) {
        sort.forEach(order -> {
            if (order.isAscending()) {
                cb.orderByAsc(order.getProperty());
            } else {
                cb.orderByDesc(order.getProperty());
            }
        });
        cb.orderByAsc(UserView_.ID);
    }
}

