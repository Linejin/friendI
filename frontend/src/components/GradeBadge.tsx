import React from 'react';
import { MemberGrade, GRADE_INFO } from '../types';

interface GradeBadgeProps {
  grade: MemberGrade;
}

const GradeBadge: React.FC<GradeBadgeProps> = ({ grade }) => {
  const info = GRADE_INFO[grade];
  
  return (
    <span className={`grade-badge ${info.color}`}>
      {info.emoji} {info.description}
    </span>
  );
};

export default GradeBadge;