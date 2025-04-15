/*
  SortTable
  version 2 (Modernized)
  Original: 7th April 2007, Stuart Langridge, http://www.kryogenix.org/code/browser/sorttable/
  Modernized: [Current Date]

  Instructions:
  Download this file
  Add <script src="sorttable.js"></script> to your HTML
  Add class="sortable" to any table you'd like to make sortable
  Click on the headers to sort

  Licenced as X11: http://www.kryogenix.org/code/browser/licence.html
  This basically means: do what you want with it.
*/

const sorttable = {
  DATE_RE: /^(\d{1,2})[\/\.-](\d{1,2})[\/\.-]((\d{2})?\d{2})$/, // Regex for date parsing dd/mm/yyyy or mm/dd/yyyy
  SORT_COLUMN_INDEX: 'sorttable_columnindex', // Custom attribute to store column index

  init: function() {
    // quit if this function has already been called
    if (this.initialized) return;
    this.initialized = true;

    if (!document.createElement || !document.getElementsByTagName) return;

    document.querySelectorAll('table.sortable').forEach(table => {
      this.makeSortable(table);
    });
  },

  makeSortable: function(table) {
    if (!table.tHead) {
      // table doesn't have a tHead. Create one and put the first row in it.
      const the = document.createElement('thead');
      if (table.rows.length > 0) {
        the.appendChild(table.rows[0]);
        table.insertBefore(the, table.firstChild);
      } else {
        // Cannot make an empty table sortable
        return;
      }
    }
    // Ensure tHead is correctly referenced (needed for some older browser compatibility, safe otherwise)
    if (table.tHead == null) table.tHead = table.getElementsByTagName('thead')[0];

    if (table.tHead.rows.length !== 1) return; // Can't cope with multiple header rows

    // Handle backwards compatibility for "sortbottom" class (move to tfoot)
    const sortbottomrows = [];
    // Use Array.from for iterating HTMLCollection
    Array.from(table.rows).forEach(row => {
      if (row.classList.contains('sortbottom')) {
        sortbottomrows.push(row);
      }
    });

    if (sortbottomrows.length > 0) {
      let tfo = table.tFoot;
      if (!tfo) {
        // table doesn't have a tfoot. Create one.
        tfo = document.createElement('tfoot');
        table.appendChild(tfo);
      }
      sortbottomrows.forEach(row => {
        tfo.appendChild(row);
      });
    }

    // Work through each header cell
    const headrow = table.tHead.rows[0].cells;
    for (let i = 0; i < headrow.length; i++) {
      const cell = headrow[i];
      // Skip columns with 'sorttable_nosort' class
      if (!cell.classList.contains('sorttable_nosort')) {
        let sortFunc;
        // Check for manual override sorttable_type
        const match = cell.className.match(/\bsorttable_([a-z0-9]+)\b/);
        const override = match ? match[1] : null;

        if (override && typeof this[`sort_${override}`] === 'function') {
          sortFunc = this[`sort_${override}`];
        } else {
          sortFunc = this.guessType(table, i);
        }

        // Make header clickable
        cell.sorttable_sortfunction = sortFunc;
        cell.setAttribute(this.SORT_COLUMN_INDEX, i); // Store index using attribute
        // Use standard addEventListener
        cell.addEventListener('click', (e) => this.headerClick(e));

        // Add visual cue for sortable columns
        cell.style.cursor = 'pointer';
      }
    }
  },

  headerClick: function(e) {
    const cell = e.currentTarget; // The header cell that was clicked
    const table = cell.closest('table');
    const columnIndex = parseInt(cell.getAttribute(this.SORT_COLUMN_INDEX), 10);
    const tbody = table.tBodies[0];

    if (!tbody || isNaN(columnIndex)) return; // Safety check

    const sortFunction = cell.sorttable_sortfunction;
    const isSorted = cell.classList.contains('sorttable_sorted');
    const isSortedReverse = cell.classList.contains('sorttable_sorted_reverse');

    // Function to update sort indicators
    const updateIndicator = (targetCell, direction) => {
      // Remove existing indicators
      targetCell.querySelectorAll('.sorttable_sortindicator').forEach(span => span.remove());
      // Add new indicator
      const indicator = document.createElement('span');
      indicator.className = 'sorttable_sortindicator';
      indicator.innerHTML = direction === 'forward' ? '&nbsp;&#x25BE;' : '&nbsp;&#x25B4;'; // Down / Up arrow
      targetCell.appendChild(indicator);
    };

    // Remove sorting classes and indicators from all headers in this row
    cell.parentNode.querySelectorAll('th, td').forEach(siblingCell => {
      siblingCell.classList.remove('sorttable_sorted', 'sorttable_sorted_reverse');
      siblingCell.querySelectorAll('.sorttable_sortindicator').forEach(span => span.remove());
    });

    if (isSorted) {
      // If already sorted by this column, just reverse the table body
      this.reverse(tbody);
      cell.classList.add('sorttable_sorted_reverse');
      updateIndicator(cell, 'reverse');
    } else if (isSortedReverse) {
       // If sorted reverse, sort forward again (effectively re-reversing)
       // This requires a full sort, not just reversing the current order
       this.fullSort(tbody, columnIndex, sortFunction);
       cell.classList.add('sorttable_sorted');
       updateIndicator(cell, 'forward');
    } else {
      // New sort
      this.fullSort(tbody, columnIndex, sortFunction);
      cell.classList.add('sorttable_sorted');
      updateIndicator(cell, 'forward');
    }
  },

  fullSort: function(tbody, columnIndex, sortFunction) {
      // Build an array to sort (Schwartzian transform)
      const rowArray = [];
      Array.from(tbody.rows).forEach(row => {
          const cell = row.cells[columnIndex];
          const sortKey = this.getInnerText(cell);
          rowArray.push([sortKey, row]);
      });

      // Sort the array using the determined sort function
      rowArray.sort(sortFunction);

      // Append rows back to the tbody in the new order
      rowArray.forEach(item => {
          tbody.appendChild(item[1]);
      });
  },

  guessType: function(table, column) {
    // Guess the type of a column based on its first non-blank row
    let sortfn = this.sort_alpha; // Default to alpha sort

    if (!table.tBodies || !table.tBodies[0]) return sortfn; // No body to guess from

    const tbody = table.tBodies[0];
    for (let i = 0; i < tbody.rows.length; i++) {
      const cell = tbody.rows[i].cells[column];
      if (!cell) continue; // Skip if cell doesn't exist

      const text = this.getInnerText(cell);
      if (text !== '') {
        // Check for numeric types (including currency and percentages)
        if (text.match(/^-?[\£$¤]?[\d,.]+%?$/)) {
          return this.sort_numeric;
        }
        // Check for a date: dd/mm/yyyy or dd/mm/yy or mm/dd/yyyy etc.
        const possdate = text.match(this.DATE_RE);
        if (possdate) {
          // Looks like a date
          const first = parseInt(possdate[1], 10);
          const second = parseInt(possdate[2], 10);
          if (first > 12) {
            // Definitely dd/mm
            return this.sort_ddmm;
          } else if (second > 12) {
            // Definitely mm/dd
            return this.sort_mmdd;
          } else {
            // Ambiguous (e.g., 01/02/2023). Default to dd/mm but continue checking other rows.
            // If a later row is unambiguously mm/dd, that will take precedence.
            sortfn = this.sort_ddmm;
          }
        }
      }
    }
    return sortfn;
  },

  getInnerText: function(node) {
    // Gets the text we want to use for sorting for a cell.
    // Strips leading and trailing whitespace.
    // Special handling for custom key attribute and input fields.

    if (!node) return "";

    // Check for custom sort key attribute first
    const customKey = node.getAttribute("sorttable_customkey");
    if (customKey != null) {
      return customKey;
    }

    // Handle input fields
    if (node.tagName === 'INPUT' && node.value) {
        return node.value.trim();
    }

    // Use textContent for modern browsers (strips tags)
    if (typeof node.textContent !== 'undefined') {
      return node.textContent.trim();
    }

    // Fallback (might include tags in older environments, less likely needed now)
    if (typeof node.innerText !== 'undefined') {
      return node.innerText.trim();
    }

    // Recursive fallback for complex node structures (rarely needed with textContent)
    let innerText = '';
    Array.from(node.childNodes).forEach(child => {
        innerText += this.getInnerText(child);
    });
    return innerText.trim();

  },

  reverse: function(tbody) {
    // Reverse the rows in a tbody
    const rows = Array.from(tbody.rows);
    rows.reverse().forEach(row => tbody.appendChild(row));
  },

  /* === Sort Functions ===
     Each sort function takes two parameters, a and b (arrays from fullSort: [sortKey, rowElement])
     Compare a[0] and b[0]
  */
  sort_numeric: function(a, b) {
    // Clean string, parse float, default to 0 if NaN
    const aa = parseFloat(String(a[0]).replace(/[^0-9.-]/g, '')) || 0;
    const bb = parseFloat(String(b[0]).replace(/[^0-9.-]/g, '')) || 0;
    return aa - bb;
  },

  sort_alpha: function(a, b) {
    const strA = String(a[0]).toLowerCase();
    const strB = String(b[0]).toLowerCase();
    if (strA === strB) return 0;
    if (strA < strB) return -1;
    return 1;
  },

  // Helper for date sorting
  _parseDate: function(text, format) {
      const match = text.match(sorttable.DATE_RE);
      if (!match) return 0; // Or handle as invalid date

      let year = parseInt(match[3], 10);
      let month, day;

      if (format === 'ddmm') {
          day = parseInt(match[1], 10);
          month = parseInt(match[2], 10);
      } else { // mmdd
          month = parseInt(match[1], 10);
          day = parseInt(match[2], 10);
      }

      // Handle 2-digit years (assume 20xx or 19xx)
      if (match[4]) { // If year had only 2 digits initially
          year += (year < 70 ? 2000 : 1900); // Adjust century (adjust threshold if needed)
      }

      // Pad month and day for consistent string comparison YYYYMMDD
      const mm = String(month).padStart(2, '0');
      const dd = String(day).padStart(2, '0');

      return parseInt(`${year}${mm}${dd}`, 10);
  },

  sort_ddmm: function(a, b) {
    const dt1 = sorttable._parseDate(a[0], 'ddmm');
    const dt2 = sorttable._parseDate(b[0], 'ddmm');
    return dt1 - dt2;
  },

  sort_mmdd: function(a, b) {
    const dt1 = sorttable._parseDate(a[0], 'mmdd');
    const dt2 = sorttable._parseDate(b[0], 'mmdd');
    return dt1 - dt2;
  },

  // shaker_sort (stable sort) is generally not needed as Array.prototype.sort
  // is stable in modern JavaScript engines (ES2019+). Kept for reference if needed.
  /*
  shaker_sort: function(list, comp_func) {
    // ... (original implementation using let/const) ...
  }
  */
};

// --- Initialization ---
// Use DOMContentLoaded which is more reliable and fires earlier than window.onload
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => sorttable.init());
} else {
  // Handle cases where the script is loaded after DOMContentLoaded
  sorttable.init();
}
