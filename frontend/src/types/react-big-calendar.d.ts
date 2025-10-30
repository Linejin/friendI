// React Big Calendar 타입 선언
declare module 'react-big-calendar' {
  import { ComponentType } from 'react';

  export interface Event {
    title: string;
    start: Date;
    end: Date;
    allDay?: boolean;
    resource?: any;
  }

  export type View = 'month' | 'week' | 'work_week' | 'day' | 'agenda';

  export const Views: {
    MONTH: 'month';
    WEEK: 'week';
    WORK_WEEK: 'work_week';
    DAY: 'day';
    AGENDA: 'agenda';
  };

  export interface SlotInfo {
    start: Date;
    end: Date;
    slots: Date[];
    action: 'select' | 'click' | 'doubleClick';
  }

  export interface CalendarProps {
    localizer: any;
    events: Event[];
    startAccessor?: string | ((event: Event) => Date);
    endAccessor?: string | ((event: Event) => Date);
    titleAccessor?: string | ((event: Event) => string);
    allDayAccessor?: string | ((event: Event) => boolean);
    resourceAccessor?: string | ((event: Event) => any);
    view?: View;
    views?: View[] | { [key: string]: boolean | ComponentType<any> };
    date?: Date;
    onView?: (view: View) => void;
    onNavigate?: (date: Date) => void;
    onSelectSlot?: (slotInfo: SlotInfo) => void;
    onSelectEvent?: (event: Event) => void;
    onDoubleClickEvent?: (event: Event) => void;
    selectable?: boolean | 'ignoreEvents';
    eventPropGetter?: (
      event: Event,
      start: Date,
      end: Date,
      isSelected: boolean
    ) => { className?: string; style?: React.CSSProperties };
    slotPropGetter?: (date: Date) => { className?: string; style?: React.CSSProperties };
    dayPropGetter?: (date: Date) => { className?: string; style?: React.CSSProperties };
    showMultiDayTimes?: boolean;
    max?: Date;
    min?: Date;
    scrollToTime?: Date;
    culture?: string;
    formats?: { [key: string]: any };
    messages?: { [key: string]: any };
    timeslots?: number;
    step?: number;
    toolbar?: boolean;
    popup?: boolean;
    popupOffset?: number | { x: number; y: number };
    onDrillDown?: (date: Date, view: View) => void;
    onShowMore?: (events: Event[], date: Date) => void;
    doShowMoreDrillDown?: boolean;
    length?: number;
    style?: React.CSSProperties;
    className?: string;
    elementProps?: React.HTMLAttributes<HTMLDivElement>;
    [key: string]: any;
  }

  export const Calendar: ComponentType<CalendarProps>;

  export function momentLocalizer(moment: any): any;
  export function globalizeLocalizer(globalize: any): any;
  export function luxonLocalizer(luxon: any, options?: any): any;
  export function dayjsLocalizer(dayjs: any): any;

  export default Calendar;
}

declare module 'react-big-calendar/lib/css/react-big-calendar.css' {
  const content: any;
  export default content;
}