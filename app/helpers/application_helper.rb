module ApplicationHelper

  include Pagy::Frontend


  #styles
    def style_side_ul
      'flex flex-col gap-0 m-0 p-0 h-screen bg-slate-100 dark:bg-slate-800 w-16'
    end

    def style_side_li
      'w-16 h-16 bg-slate-50 dark:bg-slate-900 flex flex-col items-center justify-center rounded shadow-sm hover:bg-slate-100 dark:hover:bg-slate-800'
    end

    def style_side_a(link = '/')
      "text-xs flex flex-col justify-center h-full w-full items-center text-center sidelinx text-slate-700 dark:text-slate-300 hover:text-slate-900 dark:hover:text-slate-100 #{active_class(link)} "
    end

    def style_side_a_home
      style_side_a + 'py-4 w-full'
    end
  # end styles

  def comp_code(i,f,v)
    i + f + v
  end

  # forms
  #
  def form_container
    'shadow-sm p-2 bg-slate-50 dark:bg-slate-800/50'
  end

  def style_form_group
    'flex gap-4 w-full py-2 px-1'
  end

  def label_class
    'text-xs font-semibold block'
  end

  def select_class
    input_class(' bg-white dark:bg-slate-700') + ' dark:border-slate-600 selex'
  end

  def input_class(add = ' bg-white dark:bg-slate-700')
    'text-xs w-full  shadow block rounded-sm border-slate-50 dark:border-slate-600 outline-none px-3 py-2 mt-2' + add
  end

  def button_class(add = ' bg-green-600')
    style_main_btn(add)
  end

  def style_toggle_switch(form, attribute, label_text)
    toggle_html = form.check_box(attribute, class: "sr-only peer") +
      tag.div("", class: "w-9 h-5 bg-slate-200 dark:bg-slate-700 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white dark:after:bg-slate-300 after:border-slate-300 dark:after:border-slate-600 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-accent")
    tag.label(class: "relative inline-flex items-center gap-2 cursor-pointer") do
      (toggle_html + tag.span(label_text, class: "text-xs text-slate-400 dark:text-slate-300 uppercase tracking-wide")).html_safe
    end
  end


  # end forms

  def style_container_head
    'flex gap-4 justify-between items-center border-b border-slate-300 dark:border-slate-600 text-center'
  end

  def style_subcontainer_hor
    'w-full flex items-center w-1/3'
  end

  def style_subcontainer_linx(link = '/')
    "block w-12 h-12 p-2 border border-slate-100 dark:border-slate-600 flex items-center justify-center rounded-full #{active_class(link)}"
  end

  def style_main_cnt
    'bg-white dark:bg-slate-800 rounded-none border-l border-r border-b border-slate-200 dark:border-slate-600 py-16 px-5'
  end

  def style_main_header_container
    'flex gap-8 items-center py-4 bg-slate-50 dark:bg-slate-800 border-b-4 border-slate-200 dark:border-slate-700 overflow-hidden relative'
  end

  def style_main_header
    'title-gen'
  end

  def style_main_card_grid
    'grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8'
  end

  def style_main_card
    'bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-600 shadow-sm px-6 py-4'
  end

  def style_main_card_header
    'text-base font-semibold text-slate-800 dark:text-slate-200 border-b border-slate-100 dark:border-slate-600 pb-3 mb-5 flex items-center gap-2'
  end

  def style_main_card_link
    'flex items-center justify-between px-3 py-2.5 bg-slate-50 dark:bg-slate-800/50 hover:bg-slate-100 dark:hover:bg-slate-700 hover:border-l-2 hover:border-accent transition-all rounded-sm text-slate-700 dark:text-slate-200'
  end

  def style_main_card_badge
    'bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-200 text-xs font-semibold px-2.5 py-0.5 rounded'
  end

  # calendar
  def calendar_cell_classes(day, today, selected)
    base = 'border-r border-b border-slate-200 dark:border-slate-700 p-1.5 h-24 align-top relative'
    base += ' bg-slate-50 dark:bg-slate-800/50' if day.month != today.month && day != selected
    base += ' bg-amber-50 dark:bg-amber-900/30' if day == today
    base += ' bg-accent-100 dark:bg-accent-800' if day == selected
    base
  end

  def calendar_day_classes(day, today, selected)
    base = 'text-xs leading-none'
    base += ' text-slate-900 dark:text-slate-100 font-medium' if day == today
    base += ' text-slate-700 dark:text-slate-300' if day != today && day.month == today.month
    base += ' text-slate-500 dark:text-slate-400' if day.month != today.month
    base
  end

  def calendar_day_wrapper_classes(day, selected)
    base = 'inline-flex items-center justify-center w-7 h-7'
    base += ' rounded-full shadow-lg' if day == selected
    base
  end

  def calendar_events_for_day(day, events)
    events.select { |e| (e.start_time..e.end_time).cover?(day) }
  end

  def calendar_month_name(date)
    t('date.month_names')[date.month]
  end

  def calendar_weekdays
    %w[Lunedì Martedì Mercoledì Giovedì Venerdì Sabato Domenica]
  end

  def calendar_weekdays_short
    %w[Lun Mar Mer Gio Ven Sab Dom]
  end
  # end calendar

  def style_main_sub_header
    'text-2xl my-4 flex items-center p-2 lowercase font-semibold text-slate-600 dark:text-slate-200 border-b border-t border-slate-200 dark:border-slate-600 py-4'
  end

  def style_main_lists
    'my-8 flex gap-4 flex-wrap items-start'
  end

  def style_main_lists_no_gap
    'my-2 flex gap-0  items-start'
  end

  def style_main_lists_sub
    'my-4'
  end

  def style_main_lists_head
    'uppercase text-xl border-b border-slate-200 dark:border-slate-600 p-2'
  end

  def style_main_lists_p
    'p-2 text-sm'
  end

  def style_main_lists_p_border
    'p-4 text-sm border border-slate-400 dark:border-slate-500 h-14'
  end

  def style_agenda_ul
    'flex flex-col gap-4 py-4 text-xs '
  end
  def style_agenda_li
    'border-b p-1 border-slate-200 dark:border-slate-700 w-full'
  end

  def style_actions_linx
    'rounded-lg py-1 px-3 bg-gray-100 dark:bg-slate-700 inline-block font-semibold text-xs whitespace-nowrap'
  end

  def style_action_pdf
    "#{style_actions_linx} bg-red-500 uppercase text-white"
  end

  def style_action_pdf_small
    "text-xs font-semibold bg-red-500 text-white p-2"
  end

  def style_main_lists_subtitle
    'my-6 grow uppercase text-sm text-slate-600 dark:text-slate-300'
  end

  def style_main_lists_subtitle_nomarg
    'grow uppercase text-sm text-slate-600 dark:text-slate-300'
  end

  def style_main_input
    'p-2 border border-slate-500 dark:border-slate-600 dark:bg-slate-700 dark:text-slate-200'
  end

  def style_table_th
    'p-3 bg-slate-100 dark:bg-slate-700 text-xs font-normal lowercase text-start border border-slate-200 dark:border-slate-700'
  end

  def style_table_td
    'text-xs p-3 border border-slate-300 dark:border-slate-600'
  end

  def style_table_td_parent
    'text-sm border border-slate-300 dark:border-slate-600'
  end

  def style_table_th_children
    'p-2 bg-slate-50 dark:bg-slate-800 text-xs uppercase text-start border-r border-slate-200 dark:border-slate-700'
  end

  def style_table_td_children
    'p-2 text-sm border border-slate-300 dark:border-slate-600'
  end


  def style_input
    'p-2 border-slate-400 dark:border-slate-500 text-xs dark:bg-slate-700 dark:text-slate-200'
  end

  def style_select_class
    'w-full bg-white dark:bg-slate-700 border border-slate-300 dark:border-slate-600 rounded px-3 py-2 text-xs'
  end

  def style_search_input
    style_input + ' w-96 border border-accent-100 dark:border-accent-700 shadow-sm'
  end

  def style_main_btn(add = ' bg-accent')
    'py-1 px-2 text-white tracking-wide text-xs rounded-sm inline-block cursor-pointer' + add
  end

  def style_main_btn_icon
    'my-6 bg-accent-800 text-white tracking-wide inline-block cursor-pointer hover:bg-accent-700 h-10 w-10 rounded-sm'
  end

  def style_import_form
    'bg-slate-50 dark:bg-slate-900 p-4'
  end

  def style_import_field
    'w-full bg-white dark:bg-slate-700 border border-slate-300 dark:border-slate-600 rounded px-3 py-1.5 text-xs file:bg-accent file:text-white file:border-0 file:rounded file:px-3 file:py-1 file:mr-2 file:cursor-pointer file:text-xs file:font-medium'
  end

  def style_import_btn
    'px-5 py-2 bg-accent text-white tracking-wider rounded-sm uppercase text-xs cursor-pointer hover:bg-accent-700 transition-colors'
  end

  def style_import_btn_blank
    'p-2 my-2 rounded-sm inline-block rounded-sm uppercase text-xs cursor-pointer font-semibold'
  end

  def style_import_pdf
    'p-3 my-4 bg-red-500 text-white font-bold inline-block rounded-sm'
  end

  def style_import_pdf_small
    style_import_pdf + ' text-xs'
  end



  #navigation
  #
  def active_class(link_path)
    current_page?(link_path) ? "active" : ""
  end

  def active_class_for_controllers(*controller_names)
    controller_names.include?(controller_name) ? 'active' : ''
  end

  def active_class_for_namespace(*namespaces)
    namespaces.any? { |ns| controller_path == ns || controller_path.start_with?("#{ns}/") } ? 'active' : ''
  end

  def assign_fs(tem, sez)
    case sez
    when '1'
      tem.f1
    when '2'
      tem.f2
    when '3'
      tem.f3
    when '4'
      tem.f4
    when '5'
      tem.f5
    else

    end
  end


  #viz
  #
  def show_leg(arrdesc)
    counter = 1
    arrArs = []
    arrdesc.each do |x|
      arrArs.push([counter, x])
      counter = counter + 1
    end
    return arrArs
  end

  # routines
  #
  def calc_percentage(num1, num2)
    return (num1 * 100 / (num2 * 5)).round(2)
  end

  def add_time_tempestas(arr, datex, index)
    arr[index].push(datex)
  end

  def add_count_tempestas(arr, num, index)
    arr[index].push(num)
  end

  def get_bg_tempestas(arr, qty)
    if arr.sum == qty
      bg = 'bg-green-600'
      elsif arr.sum < qty || arr.sum > 0
      bg = 'bg-amber-500'
      else
      bg = 'bg-red-500'
      end
  end

  def hasDoneTempestas?(prow)
      qty = prow.qty.to_i
      if qty == get_no_temp(prow)
        return true
      else
        return false
      end
  end

  def check_empty_gen(product)
    if product.riga1.present? || product.riga2.present? || product.riga3.present?  || product.riga4.present?  || product.riga5.present?
      return true
    end
  end

  def get_no_temp(prow)
    if prow.tempestas.size > 0
      return prow.tempestas.where('prow_id = ? and (f1 = true and f2 = true and f3 = true and f4 = true and f5 = true)', prow.id).size
    else
      return 0
    end
  end

  def get_icon_etx(notez)
    notez == '' ? addx = '<span class="material-symbols-outlined">add_2</span>' : addx = '<span class="material-symbols-outlined">edit</span>'
  end

  def icon_edit
    raw('<span class="material-symbols-outlined">edit</span>')
  end

  def out_line(mod, num)
    case num
    when 1
      return raw(mod.riga1.gsub(/\R+/, '<br/>')) if !mod.riga1.nil?
    when 2
      return raw(mod.riga2.gsub(/\R+/, '<br/>')) if !mod.riga2.nil?
    when 3
      return raw(mod.riga3.gsub(/\R+/, '<br/>')) if !mod.riga3.nil?
    when 4
      return raw(mod.riga4.gsub(/\R+/, '<br/>')) if !mod.riga4.nil?
    when 5
      return raw(mod.riga5.gsub(/\R+/, '<br/>')) if !mod.riga5.nil?
    else
      return ''
    end
  end
end
