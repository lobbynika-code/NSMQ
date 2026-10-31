export type QuestionKind = "calculation" | "non_calculation";
export const MAIN_POINTS_CORRECT=3, MAIN_POINTS_WRONG=0, BONUS_POINTS_CORRECT=1, BONUS_POINTS_WRONG_OR_TIMEOUT=-1, BUZZ_WINDOW_SECONDS=3, BONUS_ANSWER_SECONDS=3;
export function mainDurationSeconds(kind:QuestionKind):30|10{return kind==="calculation"?30:10;}
/** Display-only helper; enforce all deadlines on the server. */
export function remainingSeconds(deadlineIso:string,nowMs=Date.now()):number{return Math.max(0,Math.ceil((new Date(deadlineIso).getTime()-nowMs)/1000));}