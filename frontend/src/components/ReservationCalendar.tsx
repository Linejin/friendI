import React, { useState } from 'react';
import { Calendar, momentLocalizer, View, Views } from 'react-big-calendar';
import moment from 'moment';
import 'react-big-calendar/lib/css/react-big-calendar.css';
import { Reservation } from '../types';

// moment 한국어 설정
moment.locale('ko');
const localizer = momentLocalizer(moment);

interface ReservationCalendarProps {
  reservations: Reservation[];
  onSelectSlot: (slotInfo: { start: Date; end: Date }) => void;
  onSelectEvent: (reservation: Reservation) => void;
}

const ReservationCalendar: React.FC<ReservationCalendarProps> = ({
  reservations,
  onSelectSlot,
  onSelectEvent
}) => {
  const [view, setView] = useState<View>(Views.MONTH);
  const [date, setDate] = useState(new Date());

  console.log('ReservationCalendar received reservations:', reservations); // 디버그용

  // 예약 데이터를 달력 이벤트 형식으로 변환
  const reservationEvents = reservations.map(reservation => {
    console.log('Processing reservation:', reservation); // 디버그용
    
    try {
      // 날짜 파싱 - reservationDate는 YYYY-MM-DD 형식
      let startDateTime: Date;
      
      if (reservation.reservationDate.includes('T')) {
        // ISO 형식인 경우
        startDateTime = new Date(reservation.reservationDate);
      } else {
        // YYYY-MM-DD 형식인 경우 - 기본 시간을 10:00으로 설정
        startDateTime = new Date(`${reservation.reservationDate}T10:00:00`);
      }
      
      // 날짜가 유효한지 확인
      if (isNaN(startDateTime.getTime())) {
        throw new Error('Invalid date format');
      }
      
      const endDateTime = new Date(startDateTime);
      endDateTime.setHours(startDateTime.getHours() + 2); // 2시간 후로 설정
      
      console.log(`Reservation ${reservation.id}:`, {
        originalDate: reservation.reservationDate,
        parsedStart: startDateTime,
        parsedEnd: endDateTime
      });
      
      return {
        id: reservation.id,
        title: `${reservation.title} (${reservation.confirmedCount}/${reservation.maxCapacity})`,
        start: startDateTime,
        end: endDateTime,
        resource: reservation,
        allDay: false
      };
    } catch (error) {
      console.error('Error parsing reservation date:', error, reservation);
      // 기본값으로 오늘 10시 사용
      const now = new Date();
      now.setHours(10, 0, 0, 0);
      const later = new Date(now);
      later.setHours(12, 0, 0, 0);
      
      return {
        id: reservation.id,
        title: `${reservation.title} (날짜 오류)`,
        start: now,
        end: later,
        resource: reservation,
        allDay: false
      };
    }
  });

  // 실제 예약과 테스트 데이터 결합
  const allEvents = [...reservationEvents];
  
  console.log('=== 달력 디버그 정보 ===');
  console.log('받은 예약 데이터:', reservations);
  console.log('변환된 예약 이벤트:', reservationEvents);
  console.log('최종 달력 이벤트:', allEvents);
  console.log('===================');

  // 이벤트 스타일 설정
  const eventStyleGetter = (event: any) => {
    const reservation = event.resource as Reservation;
    const isFull = reservation.confirmedCount >= reservation.maxCapacity;
    
    return {
      style: {
        backgroundColor: isFull ? '#dc3545' : '#28a745',
        borderRadius: '4px',
        opacity: 0.8,
        color: 'white',
        border: '0px',
        display: 'block',
        fontSize: '12px'
      }
    };
  };

  // 슬롯 스타일 설정 (과거 날짜 비활성화)
  const slotStyleGetter = (date: Date) => {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    if (date < today) {
      return {
        style: {
          backgroundColor: '#f8f9fa',
          color: '#6c757d'
        }
      };
    }
    return {};
  };

  return (
    <div style={{ 
      width: '100%',
      minHeight: '700px',
      backgroundColor: 'white',
      borderRadius: '8px',
      padding: '0'
    }}>
      {/* 디버그 정보 패널 */}
      <div style={{ 
        marginBottom: '15px', 
        padding: '10px', 
        backgroundColor: '#f8f9fa', 
        borderRadius: '4px',
        fontSize: '12px'
      }}>
        <strong>디버그 정보:</strong> 예약 {reservations.length}개, 이벤트 {allEvents.length}개
        {allEvents.length > 0 && (
          <div style={{ marginTop: '5px' }}>
            다음 이벤트들이 표시됩니다: {allEvents.map(e => e.title).join(', ')}
          </div>
        )}
      </div>
      
      <div style={{ marginBottom: '20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h3>📅 예약 달력</h3>
        <div style={{ display: 'flex', gap: '10px' }}>
          <button 
            className={`button ${view === Views.MONTH ? 'button-primary' : ''}`}
            onClick={() => setView(Views.MONTH)}
            style={{ fontSize: '14px', padding: '5px 10px' }}
          >
            월
          </button>
          <button 
            className={`button ${view === Views.WEEK ? 'button-primary' : ''}`}
            onClick={() => setView(Views.WEEK)}
            style={{ fontSize: '14px', padding: '5px 10px' }}
          >
            주
          </button>
          <button 
            className={`button ${view === Views.DAY ? 'button-primary' : ''}`}
            onClick={() => setView(Views.DAY)}
            style={{ fontSize: '14px', padding: '5px 10px' }}
          >
            일
          </button>
        </div>
      </div>

      <div className="calendar-container" style={{ 
        // backgroundColor: 'white',
        // border: '1px solid #dee2e6',
        // borderRadius: '8px',
        // overflow: 'visible'
      }}>
        <Calendar
          localizer={localizer}
          events={allEvents}
          startAccessor="start"
          endAccessor="end"
          view={view}
          onView={setView}
          date={date}
          onNavigate={setDate}
          onSelectSlot={onSelectSlot}
          onSelectEvent={(event) => {onSelectEvent(event.resource);}}
          selectable={true}
          eventPropGetter={eventStyleGetter}
          slotPropGetter={slotStyleGetter}
          popup={true}
          step={60}
          timeslots={1}
          min={new Date(0, 0, 0, 9, 0, 0)} // 9시부터
          max={new Date(0, 0, 0, 18, 0, 0)} // 18시까지
          style={{ height: '100%', width: '100%' }}
        messages={{
          allDay: '종일',
          previous: '이전',
          next: '다음',
          today: '오늘',
          month: '월',
          week: '주',
          day: '일',
          agenda: '일정',
          date: '날짜',
          time: '시간',
          event: '예약',
          noEventsInRange: '이 기간에는 예약이 없습니다.',
          showMore: (total) => `+${total} 더보기`
        }}
        formats={{
          dateFormat: 'D',
          dayFormat: (date, culture, localizer) =>
            localizer?.format(date, 'dddd', culture) || '',
          dayRangeHeaderFormat: ({ start, end }, culture, localizer) =>
            `${localizer?.format(start, 'M월 D일', culture)} - ${localizer?.format(end, 'M월 D일', culture)}`,
          monthHeaderFormat: (date, culture, localizer) =>
            localizer?.format(date, 'YYYY년 M월', culture) || '',
          dayHeaderFormat: (date, culture, localizer) =>
            localizer?.format(date, 'M월 D일 dddd', culture) || '',
          timeGutterFormat: (date, culture, localizer) =>
            localizer?.format(date, 'HH:mm', culture) || '',
          eventTimeRangeFormat: ({ start, end }, culture, localizer) =>
            localizer?.format(start, 'HH:mm', culture) + ' - ' + localizer?.format(end, 'HH:mm', culture)
        }}
        />
      </div>

      <div style={{ 
        marginTop: '30px', 
        padding: '20px',
        background: 'linear-gradient(135deg, rgba(255,255,255,0.9) 0%, rgba(248,250,252,0.9) 100%)',
        borderRadius: '12px',
        border: '1px solid rgba(0,0,0,0.1)',
        fontSize: '14px',
        boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '10px' }}>
          <div style={{ 
            width: '15px', 
            height: '15px', 
            backgroundColor: '#28a745', 
            borderRadius: '3px',
            boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
          }}></div>
          <span style={{ fontWeight: '500' }}>예약 가능</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '15px' }}>
          <div style={{ 
            width: '15px', 
            height: '15px', 
            backgroundColor: '#dc3545', 
            borderRadius: '3px',
            boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
          }}></div>
          <span style={{ fontWeight: '500' }}>예약 마감</span>
        </div>
        <p style={{ 
          color: '#6c757d', 
          fontSize: '13px', 
          marginTop: '15px',
          padding: '12px',
          background: 'rgba(108, 117, 125, 0.1)',
          borderRadius: '8px',
          margin: 0,
          borderLeft: '3px solid #667eea'
        }}>
          💡 빈 시간대를 클릭하여 새 예약을 생성하거나, 기존 예약을 클릭하여 세부사항을 확인하세요.
        </p>
      </div>
    </div>
  );
};

export default ReservationCalendar;