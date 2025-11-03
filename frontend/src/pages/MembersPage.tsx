import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from 'react-query';
import { useForm } from 'react-hook-form';
import { yupResolver } from '@hookform/resolvers/yup';
import * as yup from 'yup';
import { memberService } from '../api/members';
import { Member, MemberCreateRequest, MemberGrade } from '../types';
import LoadingSpinner from '../components/LoadingSpinner';
import ErrorMessage from '../components/ErrorMessage';
import GradeBadge from '../components/GradeBadge';
import { useAuth } from '../contexts/AuthContext';

interface MemberUpdateRequest {
  name: string;
  email: string;
  phoneNumber: string;
  grade?: MemberGrade;
}

const memberSchema = yup.object({
  loginId: yup.string().required('로그인 ID는 필수입니다'),
  password: yup.string().min(4, '비밀번호는 4자 이상이어야 합니다').required('비밀번호는 필수입니다'),
  name: yup.string().required('이름은 필수입니다'),
  email: yup.string().email('올바른 이메일 형식이 아닙니다').required('이메일은 필수입니다'),
  phoneNumber: yup.string().required('전화번호는 필수입니다')
});

const editMemberSchema = yup.object({
  name: yup.string().required('이름은 필수입니다'),
  email: yup.string().email('올바른 이메일 형식이 아닙니다').required('이메일은 필수입니다'),
  phoneNumber: yup.string().required('전화번호는 필수입니다'),
  grade: yup.mixed<MemberGrade>().optional()
});

const MembersPage: React.FC = () => {
  const [showForm, setShowForm] = useState(false);
  const [searchKeyword, setSearchKeyword] = useState('');
  const [filteredMembers, setFilteredMembers] = useState<Member[]>([]);
  const [editingMember, setEditingMember] = useState<Member | null>(null);
  const [showEditToast, setShowEditToast] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10); // 페이지당 항목 수
  const queryClient = useQueryClient();
  const { user } = useAuth();

  // 현재 사용자가 관리자인지 확인
  const isAdmin = user?.grade === MemberGrade.ROOSTER;

  const { data: members, isLoading, error, refetch } = useQuery(
    'members',
    memberService.getAllMembers
  );

  // 검색 결과를 위한 쿼리
  const { data: searchResults, isLoading: isSearching, error: searchError } = useQuery(
    ['members', 'search', searchKeyword],
    () => {
      console.log('검색 API 호출:', searchKeyword);
      return memberService.searchMembers(searchKeyword);
    },
    {
      enabled: !!searchKeyword.trim(),
      staleTime: 30000, // 30초
      onError: (error) => {
        console.error('검색 에러:', error);
      },
      onSuccess: (data) => {
        console.log('검색 결과:', data);
      }
    }
  );

  const createMemberMutation = useMutation(memberService.createMember, {
    onSuccess: () => {
      queryClient.invalidateQueries('members');
      setShowForm(false);
      reset();
    }
  });

  const upgradeGradeMutation = useMutation(
    ({ id, grade }: { id: number; grade: MemberGrade }) => 
      memberService.upgradeGrade(id, grade),
    {
      onSuccess: () => {
        queryClient.invalidateQueries('members');
      }
    }
  );

  const deleteMemberMutation = useMutation(memberService.deleteMember, {
    onSuccess: () => {
      queryClient.invalidateQueries('members');
    }
  });

  const updateMemberMutation = useMutation(
    ({ id, data }: { id: number; data: any }) => memberService.updateMember(id, data),
    {
      onSuccess: () => {
        queryClient.invalidateQueries('members');
        setShowEditToast(false);
        setEditingMember(null);
        resetEdit();
      }
    }
  );

  const { register, handleSubmit, formState: { errors }, reset } = useForm<MemberCreateRequest>({
    resolver: yupResolver(memberSchema)
  });

  const { 
    register: registerEdit, 
    handleSubmit: handleSubmitEdit, 
    formState: { errors: editErrors }, 
    reset: resetEdit,
    setValue: setEditValue
  } = useForm<MemberUpdateRequest>({
    resolver: yupResolver(editMemberSchema)
  });

  // 표시할 회원 목록 결정
  const allMembers = searchKeyword.trim() 
    ? (searchResults || []) 
    : (members || []);

  // 페이지네이션 계산
  const totalPages = Math.ceil(allMembers.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const endIndex = startIndex + itemsPerPage;
  const displayMembers = allMembers.slice(startIndex, endIndex);

  // 페이지 변경 시 맨 위로 스크롤
  const handlePageChange = (page: number) => {
    setCurrentPage(page);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  // 검색 시 첫 페이지로 이동
  const handleSearchChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setSearchKeyword(e.target.value);
    setCurrentPage(1);
  };

  // 검색 초기화 시 첫 페이지로 이동
  const handleClearSearch = () => {
    setSearchKeyword('');
    setCurrentPage(1);
  };

  // 페이지당 항목 수 변경
  const handleItemsPerPageChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    setItemsPerPage(Number(e.target.value));
    setCurrentPage(1);
  };

  const onSubmit = (data: MemberCreateRequest) => {
    createMemberMutation.mutate(data);
  };

  const handleEditMember = (member: Member) => {
    setEditingMember(member);
    setEditValue('name', member.name);
    setEditValue('email', member.email);
    setEditValue('phoneNumber', member.phoneNumber);
    if (isAdmin) {
      setEditValue('grade', member.grade);
    }
    setShowEditToast(true);
  };

  const handleEditSubmit = (data: MemberUpdateRequest) => {
    if (editingMember) {
      updateMemberMutation.mutate({ id: editingMember.id, data });
    }
  };

  const handleCancelEdit = () => {
    setShowEditToast(false);
    setEditingMember(null);
    resetEdit();
  };

  const handleGradeUpgrade = (memberId: number, currentGrade: MemberGrade) => {
    // ES5 compatible: manual enum to array conversion
    const grades = [MemberGrade.EGG, MemberGrade.HATCHING, MemberGrade.CHICK, MemberGrade.YOUNG_BIRD, MemberGrade.ROOSTER];
    const currentIndex = grades.indexOf(currentGrade);
    if (currentIndex < grades.length - 1) {
      const nextGrade = grades[currentIndex + 1];
      upgradeGradeMutation.mutate({ id: memberId, grade: nextGrade });
    }
  };

  const handleDeleteMember = (memberId: number) => {
    if (window.confirm('정말 이 회원을 삭제하시겠습니까?')) {
      deleteMemberMutation.mutate(memberId);
    }
  };

  if (isLoading) {
    return <LoadingSpinner message="회원 목록을 불러오는 중..." />;
  }

  if (error) {
    return <ErrorMessage message="회원 목록을 불러오는데 실패했습니다." onRetry={refetch} />;
  }

  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">회원 관리</h1>
        <p className="page-description">
          회원을 등록하고 등급을 관리할 수 있습니다.
        </p>
      </div>

      {/* 검색 및 컨트롤 영역 */}
      <div className="card">
        <div className="search-controls">
          <div className="search-container">
            <input
              type="text"
              placeholder="이름, 이메일, 로그인ID로 검색..."
              value={searchKeyword}
              onChange={handleSearchChange}
              className="search-input"
            />
            {searchKeyword ? (
              <button onClick={handleClearSearch} className="search-clear-btn">
                ✕
              </button>
            ) : null}
            {isSearching ? <span className="search-loading">검색 중...</span> : null}
          </div>
          <button
            onClick={() => setShowForm(!showForm)}
            className="button button-primary"
            style={{ whiteSpace: 'nowrap' }}
          >
            {showForm ? '취소' : '새 회원 추가'}
          </button>
        </div>

        {/* 검색 결과 정보 */}
        {searchKeyword && !searchError ? (
          <div className="search-info">
            <span>'{searchKeyword}' 검색 결과: {displayMembers.length}명</span>
          </div>
        ) : null}

        {/* 검색 에러 메시지 */}
        {searchError ? (
          <div className="error-message">
            검색 중 오류가 발생했습니다: {String((searchError as any)?.message || '알 수 없는 오류')}
          </div>
        ) : null}
      </div>

      <div className="card">
        <div className="members-list-header">
          <div className="members-list-title">
            <h3>회원 목록 ({allMembers?.length || 0}명)</h3>
            {allMembers && allMembers.length > 0 && (
              <div className="items-per-page-selector">
                <label htmlFor="itemsPerPage">페이지당 </label>
                <select
                  id="itemsPerPage"
                  value={itemsPerPage}
                  onChange={handleItemsPerPageChange}
                  className="items-per-page-select"
                >
                  <option value={5}>5개</option>
                  <option value={10}>10개</option>
                  <option value={20}>20개</option>
                  <option value={50}>50개</option>
                </select>
                <label> 표시</label>
              </div>
            )}
          </div>
          <button 
            className="button button-primary"
            onClick={() => setShowForm(!showForm)}
            style={{ whiteSpace: 'nowrap' }}
          >
            {showForm ? '취소' : '새 회원 등록'}
          </button>
        </div>

        {showForm && (
          <div className="card" style={{ marginBottom: '20px', backgroundColor: '#f8f9fa' }}>
            <h4>새 회원 등록</h4>
            <form onSubmit={handleSubmit(onSubmit)}>
              <div className="grid grid-2">
                <div className="form-group">
                  <label className="form-label">로그인 ID</label>
                  <input
                    {...register('loginId')}
                    className="form-input"
                    placeholder="로그인 ID를 입력하세요"
                  />
                  {errors.loginId ? <div className="error">{errors.loginId.message}</div> : null}
                </div>

                <div className="form-group">
                  <label className="form-label">비밀번호</label>
                  <input
                    {...register('password')}
                    type="password"
                    className="form-input"
                    placeholder="비밀번호를 입력하세요"
                  />
                  {errors.password ? <div className="error">{errors.password.message}</div> : null}
                </div>

                <div className="form-group">
                  <label className="form-label">이름</label>
                  <input
                    {...register('name')}
                    className="form-input"
                    placeholder="이름을 입력하세요"
                  />
                  {errors.name ? <div className="error">{errors.name.message}</div> : null}
                </div>

                <div className="form-group">
                  <label className="form-label">이메일</label>
                  <input
                    {...register('email')}
                    type="email"
                    className="form-input"
                    placeholder="이메일을 입력하세요"
                  />
                  {errors.email ? <div className="error">{errors.email.message}</div> : null}
                </div>

                <div className="form-group">
                  <label className="form-label">전화번호</label>
                  <input
                    {...register('phoneNumber')}
                    className="form-input"
                    placeholder="전화번호를 입력하세요"
                  />
                  {errors.phoneNumber ? <div className="error">{errors.phoneNumber.message}</div> : null}
                </div>
              </div>

              <div style={{ marginTop: '20px' }}>
                <button 
                  type="submit" 
                  className="button button-primary"
                  disabled={createMemberMutation.isLoading}
                >
                  {createMemberMutation.isLoading ? '등록 중...' : '회원 등록'}
                </button>
              </div>
            </form>
          </div>
        )}

        {displayMembers && displayMembers.length > 0 ? (
          <div className="card">
            {/* 데스크톱 테이블 뷰 */}
            <div className="members-table-container">
              <table className="members-table">
                <thead>
                  <tr>
                    <th>이름</th>
                    <th>로그인 ID</th>
                    <th>등급</th>
                    <th>이메일</th>
                    <th>전화번호</th>
                    <th>가입일</th>
                    <th>액션</th>
                  </tr>
                </thead>
                <tbody>
                  {displayMembers.map((member: Member) => (
                    <tr key={member.id}>
                      <td><strong>{member.name}</strong></td>
                      <td style={{ color: '#6c757d' }}>@{member.loginId}</td>
                      <td><GradeBadge grade={member.grade} /></td>
                      <td style={{ fontSize: '14px' }}>{member.email}</td>
                      <td style={{ fontSize: '14px' }}>{member.phoneNumber}</td>
                      <td style={{ fontSize: '14px', color: '#6c757d' }}>
                        {new Date(member.createdAt).toLocaleDateString()}
                      </td>
                      <td>
                        <div className="member-actions">
                          <button
                            className="button button-primary"
                            style={{ fontSize: '12px', padding: '5px 10px' }}
                            onClick={() => handleEditMember(member)}
                            disabled={updateMemberMutation.isLoading}
                          >
                            수정
                          </button>
                          <button
                            className="button button-danger"
                            style={{ fontSize: '12px', padding: '5px 10px' }}
                            onClick={() => handleDeleteMember(member.id)}
                            disabled={deleteMemberMutation.isLoading}
                          >
                            삭제
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {/* 모바일 카드 뷰 */}
            <div className="members-mobile-cards">
              {displayMembers.map((member: Member) => (
                <div key={member.id} className="member-card">
                  <div className="member-card-header">
                    <div>
                      <div className="member-card-name">{member.name}</div>
                      <div className="member-card-id">@{member.loginId}</div>
                    </div>
                    <GradeBadge grade={member.grade} />
                  </div>
                  
                  <div className="member-card-info">
                    <div className="member-info-row">
                      <span className="member-info-label">이메일</span>
                      <span className="member-info-value">{member.email}</span>
                    </div>
                    <div className="member-info-row">
                      <span className="member-info-label">전화번호</span>
                      <span className="member-info-value">{member.phoneNumber}</span>
                    </div>
                    <div className="member-info-row">
                      <span className="member-info-label">가입일</span>
                      <span className="member-info-value">
                        {new Date(member.createdAt).toLocaleDateString()}
                      </span>
                    </div>
                  </div>
                  
                  <div className="member-card-actions">
                    <button
                      className="button button-primary"
                      onClick={() => handleEditMember(member)}
                      disabled={updateMemberMutation.isLoading}
                    >
                      수정
                    </button>
                    <button
                      className="button button-danger"
                      onClick={() => handleDeleteMember(member.id)}
                      disabled={deleteMemberMutation.isLoading}
                    >
                      삭제
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        ) : (
          <div style={{ textAlign: 'center', padding: '50px', color: '#6c757d' }}>
            <h3>등록된 회원이 없습니다</h3>
            <p>새 회원을 등록해보세요!</p>
          </div>
        )}

        {/* 페이지네이션 */}
        {displayMembers && displayMembers.length > 0 && totalPages > 1 && (
          <div className="pagination-container">
            <div className="pagination">
              <button
                className={`pagination-btn ${currentPage === 1 ? 'disabled' : ''}`}
                onClick={() => handlePageChange(currentPage - 1)}
                disabled={currentPage === 1}
              >
                ‹ 이전
              </button>
              
              {/* 페이지 번호들 */}
              {Array.from({ length: totalPages }, (_, i) => i + 1).map(page => {
                // 현재 페이지 주변 5개 페이지만 표시
                if (
                  page === 1 || 
                  page === totalPages || 
                  (page >= currentPage - 2 && page <= currentPage + 2)
                ) {
                  return (
                    <button
                      key={page}
                      className={`pagination-btn ${page === currentPage ? 'active' : ''}`}
                      onClick={() => handlePageChange(page)}
                    >
                      {page}
                    </button>
                  );
                } else if (
                  page === currentPage - 3 || 
                  page === currentPage + 3
                ) {
                  return <span key={page} className="pagination-ellipsis">...</span>;
                }
                return null;
              })}
              
              <button
                className={`pagination-btn ${currentPage === totalPages ? 'disabled' : ''}`}
                onClick={() => handlePageChange(currentPage + 1)}
                disabled={currentPage === totalPages}
              >
                다음 ›
              </button>
            </div>
            
            <div className="pagination-info">
              {allMembers.length > 0 && (
                <span>
                  전체 {allMembers.length}명 중 {startIndex + 1}-{Math.min(endIndex, allMembers.length)}명 표시
                  ({currentPage}/{totalPages} 페이지)
                </span>
              )}
            </div>
          </div>
        )}
      </div>

      {/* 회원 정보 수정 토스트 */}
      {showEditToast && editingMember && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          backgroundColor: 'rgba(0, 0, 0, 0.5)',
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          zIndex: 1000
        }}>
          <div className="card" style={{
            width: '500px',
            maxWidth: '90vw',
            maxHeight: '90vh',
            overflow: 'auto'
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
              <h3>회원 정보 수정</h3>
              <button 
                onClick={handleCancelEdit}
                style={{ background: 'none', border: 'none', fontSize: '24px', cursor: 'pointer' }}
              >
                ×
              </button>
            </div>

            <form onSubmit={handleSubmitEdit(handleEditSubmit)}>
              <div className="form-group">
                <label className="form-label">이름</label>
                <input
                  {...registerEdit('name')}
                  className="form-input"
                  placeholder="이름을 입력하세요"
                />
                {editErrors.name ? <div className="error">{editErrors.name?.message}</div> : null}
              </div>

              <div className="form-group">
                <label className="form-label">이메일</label>
                <input
                  {...registerEdit('email')}
                  type="email"
                  className="form-input"
                  placeholder="이메일을 입력하세요"
                />
                {editErrors.email ? <div className="error">{editErrors.email?.message}</div> : null}
              </div>

              <div className="form-group">
                <label className="form-label">전화번호</label>
                <input
                  {...registerEdit('phoneNumber')}
                  className="form-input"
                  placeholder="전화번호를 입력하세요"
                />
                {editErrors.phoneNumber ? <div className="error">{editErrors.phoneNumber?.message}</div> : null}
              </div>

              {isAdmin && (
                <div className="form-group">
                  <label className="form-label">등급 (관리자 전용)</label>
                  <select
                    {...registerEdit('grade')}
                    className="form-input"
                  >
                    <option value={MemberGrade.EGG}>🥚 알</option>
                    <option value={MemberGrade.HATCHING}>🐣 부화중</option>
                    <option value={MemberGrade.CHICK}>🐥 병아리</option>
                    <option value={MemberGrade.YOUNG_BIRD}>🐤 어린새</option>
                    <option value={MemberGrade.ROOSTER}>🐔 관리자</option>
                  </select>
                  {editErrors.grade ? <div className="error">{editErrors.grade?.message}</div> : null}
                </div>
              )}

              <div style={{ display: 'flex', gap: '10px', marginTop: '20px' }}>
                <button 
                  type="submit" 
                  className="button button-primary"
                  disabled={updateMemberMutation.isLoading}
                  style={{ flex: 1 }}
                >
                  {updateMemberMutation.isLoading ? '수정 중...' : '수정 완료'}
                </button>
                <button 
                  type="button" 
                  className="button button-secondary"
                  onClick={handleCancelEdit}
                  style={{ flex: 1 }}
                >
                  취소
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default MembersPage;