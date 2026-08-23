// Helper functions for formatting task due dates, times, and recurrence rules

function formatDueDate(item) {
    if (!item) return "";
    const dateStr = item.due_date || (item.due ? item.due.split("T")[0] : "");
    if (!dateStr) return "";

    const parts = dateStr.split("-");
    if (parts.length < 3) return dateStr;
    const itemYear = parseInt(parts[0], 10);
    const itemMonth = parseInt(parts[1], 10) - 1;
    const itemDay = parseInt(parts[2], 10);

    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const targetDate = new Date(itemYear, itemMonth, itemDay);

    const diffTime = targetDate.getTime() - today.getTime();
    const diffDays = Math.round(diffTime / (1000 * 60 * 60 * 24));

    const monthNames = [
        "ene", "feb", "mar", "abr", "may", "jun",
        "jul", "ago", "sep", "oct", "nov", "dic"
    ];

    let label = "";
    if (diffDays === 0) {
        label = "Hoy";
    } else if (diffDays === 1) {
        label = "Mañana";
    } else if (diffDays === -1) {
        label = "Ayer";
    } else if (itemYear === now.getFullYear()) {
        label = `${itemDay} ${monthNames[itemMonth] || ""}`;
    } else {
        label = `${itemDay} ${monthNames[itemMonth] || ""} ${itemYear}`;
    }

    if (item.has_time && item.due_time) {
        label += `, ${item.due_time}`;
    }

    return label;
}

function isOverdue(item) {
    if (!item || item.done) return false;
    const dateStr = item.due_date || (item.due ? item.due.split("T")[0] : "");
    if (!dateStr) return false;

    const parts = dateStr.split("-");
    if (parts.length < 3) return false;
    const itemYear = parseInt(parts[0], 10);
    const itemMonth = parseInt(parts[1], 10) - 1;
    const itemDay = parseInt(parts[2], 10);

    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const targetDate = new Date(itemYear, itemMonth, itemDay);

    return targetDate.getTime() < today.getTime();
}

function formatRecurrence(rec) {
    if (!rec || !rec.frequency) return "";

    const interval = rec.interval || 1;
    const freq = (rec.frequency || "DAILY").toUpperCase();

    let text = "";
    if (freq === "DAILY") {
        text = interval === 1 ? "Cada día" : `Cada ${interval} días`;
    } else if (freq === "WEEKLY") {
        const daysMap = { "MO": "Lu", "TU": "Ma", "WE": "Mi", "TH": "Ju", "FR": "Vi", "SA": "Sá", "SU": "Do" };
        const weekdays = Array.isArray(rec.weekdays) ? rec.weekdays.map(d => daysMap[d] || d).join(", ") : "";
        if (interval === 1) {
            text = weekdays ? `Semanal (${weekdays})` : "Semanal";
        } else {
            text = weekdays ? `Cada ${interval} sem (${weekdays})` : `Cada ${interval} semanas`;
        }
    } else if (freq === "MONTHLY") {
        if (rec.monthly_type === "weekday_position") {
            const posMap = { "FIRST": "1°", "SECOND": "2°", "THIRD": "3°", "FOURTH": "4°", "LAST": "último" };
            const dayMap = { "MO": "lunes", "TU": "martes", "WE": "miércoles", "TH": "jueves", "FR": "viernes", "SA": "sábado", "SU": "domingo" };
            const p = posMap[rec.month_pos] || rec.month_pos || "1°";
            const d = dayMap[rec.month_weekday] || rec.month_weekday || "día";
            text = interval === 1 ? `Mensual (${p} ${d})` : `Cada ${interval} meses (${p} ${d})`;
        } else {
            const dayNum = rec.month_day || 1;
            text = interval === 1 ? `Mensual (día ${dayNum})` : `Cada ${interval} meses (día ${dayNum})`;
        }
    } else if (freq === "YEARLY") {
        text = interval === 1 ? "Cada año" : `Cada ${interval} años`;
    }

    if (rec.end_type === "date" && rec.end_date) {
        text += ` hasta ${rec.end_date}`;
    } else if (rec.end_type === "count" && rec.end_count) {
        text += ` (${rec.end_count} veces)`;
    }

    return text;
}
