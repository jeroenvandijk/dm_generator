module DmGeneratorHelper
	# Returns a html listing of objects indentified by their attribute
	def list_of(objects, attribute)
		list = objects.inject('') do |list_items, object| 
			list_items << content_tag(:li, h(object.send(attribute) ) )
		end

		content_tag(:ul, list)
	end
	
	
end