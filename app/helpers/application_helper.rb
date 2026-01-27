module ApplicationHelper

  include Pagy::Frontend


  #styles
    def style_side_ul
      'flex flex-col gap-0 m-0 p-0 h-screen bg-slate-100 w-16'
    end

    def style_side_li
      'w-16 h-16 bg-slate-50 flex flex-col items-center justify-center rounded shadow-sm hover:bg-slate-100'
    end

    def style_side_a(link = '/')
      "text-xs flex flex-col justify-center h-full w-full items-center text-center sidelinx text-slate-700 hover:text-slate-900 #{active_class(link)} "
    end

    def style_side_a_home
      style_side_a + 'py-4 w-full'
    end
  # end styles

  def comp_code(i,f,v)
    i + f + v
  end

  def style_container_head
    'flex gap-4 justify-between items-center border-b border-bg-slate-300 text-center'
  end

  def style_subcontainer_hor
    'w-full flex items-center w-1/3'
  end

  def style_subcontainer_linx(link = '/')
    "block w-12 h-12 p-2 border border-slate-100 flex items-center justify-center rounded-full #{active_class(link)}"
  end

  def style_main_cnt
    'mt-12'
  end

  def style_main_header
    'text-xl mt-4 mb-6 flex items-center p-2 lowercase font-semibold text-slate-600'
  end

  def style_main_sub_header
      'text-2xl my-4 flex items-center p-2 font-semibold lowercase text-slate-600  border-b border-t border-slate-200 py-4  '
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
    'uppercase text-xl border-b border-slate-200 p-2'
  end

  def style_main_lists_p
    'p-2 text-sm'
  end

  def style_main_lists_p_border
    'p-4 text-sm border border-slate-400 h-14'
  end

  def style_actions_linx
    'mt-2 rounded-lg py-2 px-5 bg-gray-100 inline-block font-semibold text-xs'
  end

  def style_action_pdf
    "#{style_actions_linx} bg-red-200"
  end

  def style_action_pdf_small
    "text-xs font-semibold bg-red-200 p-2 mt-2"
  end

  def style_main_lists_subtitle
    'my-6 grow uppercase text-sm text-slate-600'
  end

  def style_main_lists_subtitle_nomarg
    'grow uppercase text-sm text-slate-600'
  end

  def style_main_input
    'p-2 border border-slate-500'
  end

  def style_table_th
    'p-4 bg-slate-100 text-xs font-normal lowercase text-start border border-slate-200'
  end

  def style_table_td
    'text-xs p-4  border border-slate-300'
  end

  def style_table_td_parent
    'text-sm border border-slate-300'
  end

  def style_table_th_children
    'p-2 bg-slate-50 text-xs uppercase text-start border-r border-slate-200'
  end

  def style_table_td_children
    'p-2 text-sm border border-slate-300'
  end


  def style_input
    'p-2 border-slate-400'
  end

  def style_select_class
    'w-80 bg-blue-100 uppercase text-sm'
  end

  def style_search_input
    style_input + ' w-96 border border-blue-100 shadow-sm'
  end

  def style_main_btn
    'p-2 my-4 bg-indigo-400 text-white font-bold inline-block rounded-sm cursor-pointer hover:bg-indigo-500'
  end

  def style_main_btn_icon
    'my-6 bg-indigo-400 text-white font-bold inline-block rounded-sm cursor-pointer hover:bg-indigo-500 h-10 w-10'
  end

  def style_import_form
    'files flex justify-between items-center bg-blue-50 px-4'
  end

  def style_import_field
    'py-2 my-2 bg-blue-50 inline-block rounded-sm'
  end

  def style_import_btn
    'p-3 my-4 bg-blue-500 inline-block rounded-sm uppercase text-xs cursor-pointer text-white font-semibold'
  end

  def style_import_btn_blank
    'p-2 my-2  inline-block rounded-sm uppercase text-xs cursor-pointer font-semibold'
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
    return (num1 * 100 / num2).round(2)
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
      bg = 'bg.red-500'
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
