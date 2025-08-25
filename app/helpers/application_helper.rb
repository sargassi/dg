module ApplicationHelper

  def style_main_cnt
    return 'mt-12'
  end

  def style_main_lists
    return 'my-8 flex gap-4 flex-wrap items-start'
  end

  def style_main_lists_sub
    return 'my-4'
  end

  def style_main_lists_head
    return 'uppercase text-xl border-b border-slate-200 p-2'
  end

  def style_main_lists_p
    return 'p-2 text-sm'
  end

  def style_main_lists_subtitle
    return 'my-6 grow uppercase text-sm text-slate-600'
  end

  def style_main_input
    return 'p-2 border border-slate-500'
  end

  def style_import_form
    return 'files flex justify-between items-center bg-blue-50 px-4'
  end

  def style_import_field
    return 'py-4 my-4 bg-blue-50 inline-block rounded-sm'
  end

  def style_import_btn
    return 'p-4 my-4 bg-blue-200 inline-block rounded-sm uppercase text-sm cursor-pointer'
  end

  def style_import_pdf
    return 'p-4 my-4 bg-red-400 text-white font-bold inline-block rounded-sm'
  end


end
